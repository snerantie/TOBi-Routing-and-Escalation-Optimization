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

## Findings (corrected run)

1. **Vague technical intents leak the most.** `general_fault` (Avaria) misroutes
   **27.4%** and `general_difficulty` **15.2%**, vs specific topics that route well
   (connection 4.0%, TV 3.8%, device 6.1%). The bot can't disambiguate a generic
   "something's broken" and defaults to a non-technical queue.
2. **The pattern is technical → NON-technical queue.** Nearly all top leaks send
   technical topics to `T_2BI` (ACD Non-Technical) or `T_2AI` (Livechat
   Non-Technical). Biggest single leak: `general_fault → T_2BI_CFIXO` (~111.8k).
3. **Channel:** `voice` (2.56M sessions, 12.3% misroute) is the priority by
   volume; `web` routes best (6.6%).
4. **Cost = rework, not length.** Misrouted sessions average **1.02 transfers vs
   0.49** for correctly-routed and drive ~**539k extra handovers** and ~**844k
   repeat contacts**. Duration is similar across cohorts.
5. **Confidence is not usable** — virtually all technical sessions have
   `CONFIDENCE_LEVEL` = 0/blank (`confidence_band` none/unknown).

## Prioritised fixes (from d4a)

| # | Fix | Evidence | Est. volume |
|---|-----|----------|-------------|
| 1 | Route `general_fault` (Avaria, E32) to a **technical** skill (`2BII`/`2AII`) instead of `T_2BI` | leak #1-2 | ~160k |
| 2 | Add disambiguation for `general_difficulty` (intent I8) before routing | leak #3-4,6,8 | ~120k |
| 3 | Fix `connection_problem` mis-sends to ACD non-technical (`T_2BI_B`) | leak #5,9 | ~31k |
| 4 | Target the **voice** channel flow (highest volume × rate) | D3c | 2.56M base |

## Recommendation types (map each leak to one)

1. **Routing-rule fix** — a technical intent is wired to a non-technical queue
   (`T_2BI`/`T_2AI`). Re-point to the technical skill (`*II`). *Evidence: d1c, d4a.*
2. **Intent-detection / disambiguation** — generic intents (`general_fault`,
   `general_difficulty`) need a clarifying step before routing. *Evidence: d1c, d4a.*
3. **Entry-point fix** — `voice` disproportionately misroutes. Adjust its default
   routing. *Evidence: d3c.*
4. **Conversation-flow redesign** — add a technical off-ramp at the node that
   funnels faults into non-technical branches. *Evidence: d3d.*
5. **Containment / escalation path** — soft misroutes (deflected/abandoned then
   return) need a clean escalation to a technical skill. *Evidence: d8, d4a.*

## Draft scorecard (fill from d4c baseline)

> Populated above under "Validated baseline".

## Implementation support (Deliverable 5)

1. Ship the top 3–5 routing-rule fixes from `d4a`.
2. Track `d4c` weekly; compare against baseline.
3. Keep `d4d` empty — every unclassified destination must be mapped in
   `models/02` so the misroute number stays trustworthy.
