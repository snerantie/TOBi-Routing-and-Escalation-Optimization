# Recommendations framework (Deliverables 4 & 5)

This is the structure for turning query output into action. Populate the
bracketed values from `analysis/d1`–`d4` once the views are built on real data.

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

| KPI | Baseline | Target | Owner |
|-----|----------|--------|-------|
| Technical hard-misroute % | [ ] | [ ] | |
| Technical FCR % | [ ] | [ ] | |
| Repeat-contact % (technical) | [ ] | [ ] | |
| Avg handovers / technical session | [ ] | [ ] | |
| Est. agent-hours saved / month | [ ] | — | |

## Implementation support (Deliverable 5)

1. Ship the top 3–5 routing-rule fixes from `d4a`.
2. Track `d4c` weekly; compare against baseline.
3. Keep `d4d` empty — every unclassified destination must be mapped in
   `models/02` so the misroute number stays trustworthy.
