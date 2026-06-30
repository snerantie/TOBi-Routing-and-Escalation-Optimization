# Analysis Framework — 6 Steps

This document maps every artefact in this repo to the data-science lead's
6-step framework. Use it as the master index when reviewing the project.

> Lead's note: the existing analysis (`02_executive_dashboard.ipynb`,
> `standalone/d*.sql`, `docs/recommendations.md`) **mainly contributes to
> Steps 4-6**. The objective is not to redo the work, but to **build firmer
> foundations in Steps 1-3** so those conclusions are supportable.

## Step 1 — Data Understanding
*Understand datasets, tables, joins, and business context. Define key metrics
and assumptions.*

- `notebooks/01_eda.ipynb` Sections 1-4 (sources, volumes, join integrity).
- `notebooks/01_eda.ipynb` Section 11 (`LOG` token grammar).
- `docs/tag_mappings.md` (authoritative `T_` tag, entity, intent mappings).
- `docs/methodology.md` (definitions of misroute, FCR, repeat contact).

## Step 2 — Data Validation
*Check data quality, completeness, consistency, reliability. Identify limits
and gaps.*

- `notebooks/01_eda.ipynb` Section 5 (date quality — `null`, `1900-01-01`).
- `notebooks/01_eda.ipynb` Section 12 (null/blank rates on key fields).
- `notebooks/01_eda.ipynb` Section 13b / 19b (open items needing business confirmation).
- `docs/data_cleaning.md` (every cleaning rule, with the EDA finding it addresses).

## Step 3 — Exploratory Data Analysis (EDA)
*Distributions, trends, routing patterns, escalation patterns, customer journeys.
Initial observations and hypotheses.*

- `notebooks/01_eda.ipynb` Sections 6-10 (channel, service_type, intent,
  confidence, IS_FUNCTIONAL, customer dimensions).
- `notebooks/01_eda.ipynb` **Section 14** — numeric distributions (duration,
  tokens-per-session) with mean / median / p25 / p75 / p90 / p95 / p99 + histograms.
- `notebooks/01_eda.ipynb` **Section 15** — internal-session investigation
  (per Sonia's request: which channels populate `INTERNAL_SES_LIST`?).
- `notebooks/01_eda.ipynb` **Section 16** — customer-journey depth
  (sessions-per-customer distribution).
- `notebooks/01_eda.ipynb` **Section 17** — temporal patterns (day-of-week × hour-of-day).
- `notebooks/01_eda.ipynb` **Section 18** — tag/topic vocabulary depth.

## Step 4 — Insight Validation
*Validate hypotheses, confirm root causes, quantify impact.*

- `notebooks/02_executive_dashboard.ipynb` Steps 5-6 (misroute by topic + funnel).
- `notebooks/02_executive_dashboard.ipynb` Step 7 (impact: transfers + repeats).
- `notebooks/02_executive_dashboard.ipynb` Step 8 (driver: channel).
- `standalone/d1`–`d8` (the supporting BigQuery analyses).

## Step 5 — Business Analysis
*Impact on CX, resolution time, transfers, operational load. Prioritise opportunities.*

- `notebooks/02_executive_dashboard.ipynb` Step 4 (headline KPIs).
- `notebooks/02_executive_dashboard.ipynb` Step 7 (cohort impact comparison).
- `notebooks/02_executive_dashboard.ipynb` Step 9 (segment view).
- `notebooks/02_executive_dashboard.ipynb` Step 10 (outcome mix).
- `notebooks/02_executive_dashboard.ipynb` Step 11 (when misroutes peak — staffing).

## Step 6 — Recommendations
*Routing, escalation, conversation-flow improvements. Expected benefits and next
actions.*

- `notebooks/02_executive_dashboard.ipynb` Step 12 (top misroute leaks — action list).
- `notebooks/02_executive_dashboard.ipynb` Step 13 (FCR vs misroute tracking trend).
- `docs/recommendations.md` (validated baseline + prioritised fixes + KPI scorecard).

## Next investigations (raised in the team meeting)

1. **`CD` table investigation** — Sonia noted there is a `CD` table containing a
   `SESSION_ID` that, after cleaning, can be joined to the internal session list
   for richer analysis. Confirm the table's full BigQuery path, profile its
   `SESSION_ID` cleanliness, and run a join-coverage test against
   `INTERNAL_SES_LIST` to see how much enrichment we gain.
2. **Internal-session channel validation** — Section 15 of `01_eda.ipynb`
   confirms which channels populate `INTERNAL_SES_LIST`. Use this to scope where
   the `CD` join will and won't add value.
3. **Confirm remaining open items** in `01_eda.ipynb` Section 19b before
   refreshing the dashboard numbers.
