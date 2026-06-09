# TOBi Routing & Escalation Optimization

Data-driven analysis of routing and escalation of **technical** support topics in
TOBi (Vodafone Portugal virtual assistant), aimed at directing customer requests
to the correct support channels and reducing misrouting into non-technical chat
sessions.

## Business objective

Analyse and improve the routing and escalation of technical support topics within
TOBi, ensuring customer requests reach the appropriate support channels and
reducing misrouting to non-technical sessions.

### Deliverables (and where they live)

| # | Deliverable | File |
|---|-------------|------|
| 1 | Identify patterns of incorrect routing/escalation of technical issues | [`analysis/d1_misrouting_patterns.sql`](analysis/d1_misrouting_patterns.sql) |
| 2 | Quantify impact of misrouting (resolution time, channel load, handovers, repeat contacts) | [`analysis/d2_impact_quantification.sql`](analysis/d2_impact_quantification.sql) |
| 3 | Find drivers of incorrect routing (intent detection, entry points, conversation flows) | [`analysis/d3_root_cause.sql`](analysis/d3_root_cause.sql) |
| 4 | Data-driven recommendations to improve routing logic & escalation paths | [`analysis/d4_recommendations_metrics.sql`](analysis/d4_recommendations_metrics.sql) |
| 5 | Support implementation (FCR uplift, reduced inefficiency) | tracking metrics in `d4` + [`docs/methodology.md`](docs/methodology.md) |

### Supporting analyses

| File | What it adds |
|------|--------------|
| [`analysis/d5_flow_transitions.sql`](analysis/d5_flow_transitions.sql) | Step-to-step + intent→destination edge lists (Sankey) and a topic→queue confusion matrix |
| [`analysis/d6_repeat_contact_chains.sql`](analysis/d6_repeat_contact_chains.sql) | `NEXT_SESSION_ID` continuation outcomes, contacts per customer/day, repeat rate by cohort |
| [`analysis/d7_temporal_load.sql`](analysis/d7_temporal_load.sql) | Misroute by hour / day-of-week + heatmap source for channel-load planning |
| [`analysis/d8_containment_deflection.sql`](analysis/d8_containment_deflection.sql) | Bot containment funnel + self-service deflection candidates (FCR upside) |

### Notebook

[`notebooks/tobi_routing_analysis.ipynb`](notebooks/tobi_routing_analysis.ipynb) — connects to BigQuery, reads `v_session_master`, and renders the KPIs, misroute breakdowns, impact box plots, daily trend, a Sankey of intent→destination, confusion/temporal heatmaps, opportunity sizing, and a prioritised fix list. Requires `google-cloud-bigquery pandas db-dtypes matplotlib seaborn plotly` and that the `models/` views are built first.

## Data sources

Two BigQuery tables in
`vf-pt-copsvertex-live.vfpt_dh_lake_cops_pub_investigation`:

- **`f_kafka_tobi_sessions`** — one row per **session** (entry point, intents,
  channel, outcome, continuation links).
- **`f_tobi_logs_vertex`** — one row per **log event/turn** within a session.
  Joined to sessions on `SESSION_ID`, ordered by `ROW_ID`.

### The `LOG` breadcrumb grammar

`f_tobi_logs_vertex.LOG` stores **one flow token per row**. Concatenated in
`ROW_ID` order they form the conversation trail, e.g.:

```
S_PX2_I5_E18_V613 > R_adesao > S_PX0_I0_E0_V524 > M_adicionartv internet association > T_1All_CPOS
```

| Prefix | Meaning | Sub-codes / example |
|--------|---------|---------------------|
| `S_` | Dialog **state / node** | `PX`=flow/page, `I`=intent id, `E`=entity id, `V`=node id |
| `R_` | **Route / recognized intent** | `R_adesao` (adesão = subscription/sales) |
| `M_` | **Menu / module** option chosen (free text) | `M_adicionartv internet association` |
| `T_` | **Transfer / terminus** = the queue/agent group routed to | `T_1All_CPOS` |

> **`T_` tokens are the routing/escalation decision** — the destination queue.
> This is the spine of the misrouting analysis.

#### `T_` tag grammar (validated)

`T_<n><Channel><RomanNumeral>_<ClientType>`  — e.g. `T_1AII_CPOS`

| Segment | Values | Meaning |
|---------|--------|---------|
| Channel | `A`=Livechat, `B`=Call/ACD, `F`=Service-change | destination channel |
| **Roman** | **`I`=Non-Technical, `II`=Technical, `III`=Commercial** | **support type — decides correct vs misrouted** |
| ClientType | `CPOS`=Postpaid, `CPRE`=Prepaid, `CFIXO`=Fixed, `CCOL`=Collaborator, `B`=Business, `C`=Client, `N`=Non-client | customer segment (NOT a queue type) |

So a technical-topic session routed to a `II` tag = correctly routed; routed to `I`
or `III` = misrouted. Classification lives in `models/02` and the standalone pipeline.

## Definition of "technical"

Per the business owner, **technical** topics are:

- TV features / phone (device) features questions
- Connection problems (internet / network / signal / fibre / router)
- Reporting a damaged / broken phone (repair)

These are matched against the `R_`/`M_` vocabulary, `FIRST_INTENT` and
`INTENT_LIST` in [`models/03_ref_technical_topics.sql`](models/03_ref_technical_topics.sql).

### Executive charts

Management-ready visuals live in [`reports/`](reports/), generated by
[`reports/build_exec_charts.py`](reports/build_exec_charts.py). A one-page
[`reports/figures/00_executive_dashboard.png`](reports/figures/00_executive_dashboard.png)
summarises the whole story (KPI cards + misroute-by-topic + impact + root cause +
funnel + repeat contacts). The committed PNGs use clearly-watermarked illustrative
data so the layout is reviewable now; re-run the script against the live
`v_session_master` view to replace them with real numbers. See
[`reports/README.md`](reports/README.md).

## Repo layout

```
profiling/   Phase 0 — understand volume, distributions, and the LOG vocabulary
models/      Reusable views: flow reconstruction + classifications + session master
analysis/    Deliverable queries (D1-D4) + supporting analyses (D5-D8)
notebooks/   Jupyter notebook: BigQuery connection + visualizations
reports/     Executive chart generator + rendered PNG figures
docs/        Methodology, assumptions, and validation checklist
```

## How to run

**Option A — with views (needs a writable dataset):**
1. Create (or pick) a **writable** dataset for the views. Default used in the
   scripts: `vf-pt-copsvertex-live.tobi_routing_analysis`.
   Find-and-replace this if you want a different location.
2. Run the model views in order: `models/01` → `02` → `03` → `04`.
3. Run the deliverable queries in `analysis/`.
4. Profiling queries in `profiling/` are standalone and safe to run anytime.

**Option B — no views / read-only (the "long way"):**
Use [`standalone/`](standalone/). Each file rebuilds `session_master` as a
`CREATE TEMP TABLE` (no dataset needed) then runs the deliverable. Run each file
as a single script. For notebooks, load `standalone/session_master_query.sql`
instead of the view. See [`standalone/README.md`](standalone/README.md).

## Configuration & validation

The technical-topic keywords and the technical-vs-non-technical **queue
classification are provisional** and must be validated against the real
`T_`/`R_`/`M_` vocabulary in your data. See the `TODO(validate)` markers and
[`docs/methodology.md`](docs/methodology.md#validation-checklist).
