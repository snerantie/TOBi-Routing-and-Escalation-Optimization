# Methodology & assumptions

This document explains *how* misrouting is defined and measured, so the numbers
are defensible and the classification logic can be challenged and refined.

## 1. Analytical grain

- The **session** (`f_kafka_tobi_sessions`, one row per `SESSION_ID`) is the unit
  of analysis.
- The **log trail** (`f_tobi_logs_vertex`, one token per row) is reconstructed
  per session with `STRING_AGG(... ORDER BY ROW_ID)` and split into typed token
  arrays (`S_`, `R_`, `M_`, `T_`).

## 2. Key derived concepts

| Concept | How it is derived | Source |
|---------|-------------------|--------|
| **Routing destination** | The `T_` token(s) in the trail; the *final* `T_` is the effective destination | `LOG` |
| **Escalation / handover** | Presence of any `T_` token (transfer out of the bot) and/or `INTERNAL_SES_LIST` | `LOG`, sessions |
| **Technical topic** | Keyword match over `R_`/`M_` tokens + `FIRST_INTENT` + `INTENT_LIST` | `models/03` |
| **Queue category** | Each `T_` destination mapped to `technical` / `non_technical` / `unclassified` | `models/02` |
| **Misrouted** | `technical topic` **AND** routed to a `non_technical` queue (or kept in a non-technical flow with no technical resolution) | `models/04` |
| **Resolution time** | `END_MOMENT - START_MOMENT` | sessions |
| **Repeat contact** | `NEXT_SESSION_ID` populated, or same `ANI` re-contacting within a window | sessions |
| **First-contact resolution (FCR)** | Session that is functional/contained, no transfer, and no follow-on session | sessions + `LOG` |

## 3. Misrouting definitions (two complementary lenses)

1. **Hard misroute** — technical topic + final `T_` destination is a
   non-technical queue (e.g. sales/commercial like `CPOS`). The customer is
   physically sent to the wrong place.
2. **Soft misroute / containment failure** — technical topic that is *not*
   routed to a technical queue and is *not* resolved by the bot (no functional
   outcome, ends, then a `NEXT_SESSION_ID` continuation appears). The customer
   gets stuck.

Both are produced in `models/04_session_master.sql` so impact can be measured
separately or together.

## 4. Assumptions (challenge these)

- A1: The **final** `T_` token represents the effective routing outcome. If
  multiple transfers occur, intermediate ones are counted as handovers.
- A2: `IS_FUNCTIONAL` indicates the bot reached a functional/contained outcome.
  *Confirm the exact semantics* — adjust `models/04` if it means something else.
- A3: `NEXT_SESSION_ID` chains a continuation/repeat contact for the same
  customer journey.
- A4: `CONFIDENCE_LEVEL` is comparable across sessions (string buckets such as
  HIGH/MEDIUM/LOW, or a numeric string). Profiling query `p2` reveals its domain.

## 5. Validation checklist

Before trusting the deliverable numbers, validate against the data:

- [ ] Run `profiling/p3_log_vocabulary.sql` and review the full list of `T_`
      destinations; classify each as technical / non-technical in
      `models/02_ref_routing_classification.sql`.
- [ ] Review top `R_`/`M_` tokens and `FIRST_INTENT` values; refine the
      technical keyword lists in `models/03_ref_technical_topics.sql`.
- [ ] Confirm `IS_FUNCTIONAL` semantics (A2).
- [ ] Confirm `NEXT_SESSION_ID` semantics (A3).
- [ ] Sanity-check misroute volumes in `analysis/d1` against business intuition.

## 6. Configuration

- **Source dataset:** `vf-pt-copsvertex-live.vfpt_dh_lake_cops_pub_investigation`
- **Output (views) dataset:** `vf-pt-copsvertex-live.tobi_routing_analysis`
  (placeholder — change to a dataset you can write to).
- Analysis window: set via the `analysis_window` CTE / `datepart` filters at the
  top of model files.
