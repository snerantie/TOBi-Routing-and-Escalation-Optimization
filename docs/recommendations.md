# Recommendations framework (Deliverables 4 & 5)

This is the structure for turning query output into action.

## Validated baseline (corrected pipeline run)

> From the first full run on real data. Subject to a clean analysis-window filter
> (raw data has some `null`/`1900-01-01` dates — exclude those).

**Technical sessions analysed: 5,246,389**

| Outcome | Sessions | % of technical |
|---|---|---|
| Correctly handled (bot-contained or technical skill) | 2,945,887 | 56.2% |
| — bot-contained (FCR) | 782,422 | 14.9% |
| Hard misroute (technical → wrong human skill) | 525,892 | 10.0% |
| Soft misroute (deflected/abandoned/error → returns ≤24h) | 650,089 | 12.4% |
| Other technical | 1,124,521 | 21.4% |

**Total misrouted: 22.4% (~1.18M technical sessions).**

Impact (D2a): hard-misrouted technical sessions average **1.02 transfers vs 0.49**
for correctly-routed (~2×); soft-misroutes **repeat 100%** within 24h, hard-misroutes
36.9%. Session duration is similar across cohorts, so the cost is **rework
(handovers) and repeat contacts**, not single-session length.

### Baseline scorecard (monitor post-change)
| KPI | Baseline | Target | Owner |
|-----|----------|--------|-------|
| Technical hard-misroute % | 10.0% | [ ] | |
| Technical any-misroute % | 22.4% | [ ] | |
| Technical FCR (bot-contained) % | 14.9% | [ ] | |
| Avg transfers — misrouted vs correct | 1.02 vs 0.49 | [ ] | |
| Soft-misroute repeat rate | 100% | [ ] | |

---

The structure below maps query output to actions. Populate the per-leak detail
from `analysis/d4` (top intent→wrong-destination leaks).

## How to read the evidence

- **`analysis/d4` 4a** ranks every "leak" (`FIRST_INTENT` → wrong destination)
  by an impact score (volume + repeat contacts + handovers). The top rows are
  your highest-ROI routing-rule changes.
- **`analysis/d4` 4b** sizes the prize (hours saved, avoidable repeat contacts).
- **`analysis/d3`** tells you *why* each leak happens (low confidence, a specific
  entry point, or a flow step).

## Recommendation types (map each leak to one)

1. **Routing-rule fix** — a technical intent is hard-wired to a non-technical
   queue (e.g. `T_1All_CPOS`). Re-point the rule to the correct technical queue.
   *Evidence: d1c, d4a.*
2. **Intent-detection improvement** — misroutes concentrated in low
   `CONFIDENCE_LEVEL` or a confusable `FIRST_INTENT`. Add training phrases /
   disambiguation. *Evidence: d3a, d3b.*
3. **Entry-point fix** — a `CHANNEL`/`DNIS` disproportionately misroutes. Adjust
   the entry flow or default routing for that entry point. *Evidence: d1d, d3c.*
4. **Conversation-flow redesign** — a specific `R_`/`M_` step funnels technical
   users into a non-technical branch. Add a technical off-ramp / escalation
   option at that node. *Evidence: d1e, d3d.*
5. **Containment / escalation path** — soft misroutes where the bot neither
   resolves nor escalates correctly (repeat contact follows). Add a clean
   escalation to a technical queue. *Evidence: d2c, d4a.*

## Draft scorecard (fill from d4c baseline)

> Populated above under "Validated baseline".

## Implementation support (Deliverable 5)

1. Ship the top 3–5 routing-rule fixes from `d4a`.
2. Track `d4c` weekly; compare against baseline.
3. Keep `d4d` empty — every unclassified destination must be mapped in
   `models/02` so the misroute number stays trustworthy.
