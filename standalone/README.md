# Standalone (no-views) SQL — the "long way"

Use this folder if you **don't** want to create the `tobi_routing_analysis`
dataset / views. Everything here needs only **read** access to the two source
tables. Nothing persistent is created.

## How it works
Each file rebuilds `session_master` (the full `models/01 -> 04` pipeline, inlined)
as a **`CREATE TEMP TABLE`**, then runs that deliverable's queries against it.
A temp table lives only for the duration of one script run.

### IMPORTANT: run the WHOLE file at once
Select everything (Ctrl/Cmd-A) and Run. The `CREATE TEMP TABLE ...;` and the
following `SELECT`s must execute together as one script.

> **Error `session_master must be qualified with a dataset`** = you ran the
> `SELECT` on its own, after the temp table was gone. Re-run the entire file.

For a quick peek with no temp table, open `session_master_query.sql`, add
`LIMIT 100` before the final `;`, and run it (it's a single `SELECT`).

### Faster for large data: materialise once
The temp-table files rebuild the full pipeline on every run. On big tables it is
cheaper to build the table once and query it repeatedly:
```sql
CREATE OR REPLACE TABLE `your_dataset.session_master` AS
<body of session_master_query.sql>;
```
Then point d1-d8 at `your_dataset.session_master` (drop their CREATE TEMP block).

## Files
| File | Use |
|------|-----|
| `session_master_query.sql` | The full pipeline as one plain `SELECT` (one row per session). Drop into a **notebook** load cell instead of `FROM v_session_master`, or wrap in `CREATE VIEW/TABLE` later. |
| `00_session_master_build.sql` | Builds the temp table and previews 100 rows — run first to sanity-check. |
| `d1_misrouting_patterns.sql` | Deliverable 1 — misrouting patterns |
| `d2_impact_quantification.sql` | Deliverable 2 — impact (time, handovers, repeats) |
| `d3_root_cause.sql` | Deliverable 3 — drivers (confidence, entry point, flow) |
| `d4_recommendations_metrics.sql` | Deliverable 4/5 — prioritised fixes + KPI scorecard |
| `d5_flow_transitions.sql` | Flow transition / Sankey edges |
| `d6_repeat_contact_chains.sql` | Repeat-contact chains |
| `d7_temporal_load.sql` | Temporal load patterns |
| `d8_containment_deflection.sql` | Containment & deflection opportunity |

> These are **generated** from `models/` + `analysis/` (see `_build_standalone.py`
> at the repo root in history). If you change the model logic, regenerate.

## Notebook usage
In `notebooks/*.ipynb`, replace the data-load query:
```python
# before:  FROM `vf-pt-copsvertex-live.tobi_routing_analysis.v_session_master`
# after:   paste the contents of standalone/session_master_query.sql
df = client.query(open('standalone/session_master_query.sql').read()).to_dataframe()
```

## Dropping the dataset you created
If you want to remove the views/dataset entirely:
```sql
DROP SCHEMA IF EXISTS `vf-pt-copsvertex-live.tobi_routing_analysis` CASCADE;
```

## Same validation caveat
The queue classification (the override + keyword `CASE` in the pipeline) and the
technical-topic keywords are still **provisional**. Validate them against the real
`T_`/`R_`/`M_` vocabulary (run `profiling/p3`) and edit the `CASE`/`REGEXP_CONTAINS`
blocks near the top of each file.
