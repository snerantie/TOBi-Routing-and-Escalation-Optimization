# Data Cleaning — what we change, why, and where

This sits between **EDA** (`notebooks/01_eda.ipynb`) and **Analysis**
(`notebooks/02_executive_dashboard.ipynb`). It documents every cleaning /
standardisation rule applied when building `session_master`, with the EDA
finding that motivated each one.

> Order: **EDA -> Cleaning -> Analysis.** EDA discovers issues; cleaning resolves
> them; analysis answers the business question on the cleaned data.

| # | EDA finding | Cleaning rule | Where it's applied |
|---|---|---|---|
| 1 | Raw data contains `null` & `1900-01-01` dates (`01_eda` Section 5) | Apply analysis window: `DATE(START_MOMENT) BETWEEN '2024-01-01' AND '2025-12-31'` | `notebooks/02_executive_dashboard.ipynb` config + each query's `WHERE` clause |
| 2 | `CONFIDENCE_LEVEL` is a numeric score stored as string, dominated by `0`/blank (`01_eda` Section 8) | Cast to `FLOAT64` and bucket: `none / low / medium / high / unknown` | `standalone/session_master_query.sql` -> `confidence_band` |
| 3 | `IS_FUNCTIONAL` values are `Yes` / `No` / blank / null (`01_eda` Section 9) | Treat `Yes` as functional/contained -> boolean `is_functional_flag` | `standalone/session_master_query.sql` |
| 4 | `LOG` table holds one token per row (`01_eda` Section 11) | `STRING_AGG(... ORDER BY ROW_ID)` to reconstruct the trail per session | `standalone/session_master_query.sql` (CTE `flow_agg`) |
| 5 | `T_` tags follow `T_<digit><letter><roman>_<client>` (`01_eda` Section 11) | Parse digit (`1`=Contained, `2`=Transferred), letter (A/B/C/D/E/F or 2A/2B), Roman (I/II/III), client | `standalone/session_master_query.sql` (CTEs `tag_decode`, `tag_class`) |
| 6 | Technical topic is more reliably detected from entity codes than text | Flag technical from `S_` token entities `E#` (TV, connection, device, fault) + intent `I8` | `standalone/session_master_query.sql` (CTE `topic_flags`); see `docs/tag_mappings.md` |
| 7 | Repeat contact = same `ANI` re-contacting within 24h | `LEAD(START_MOMENT) OVER (PARTITION BY ANI ORDER BY START_MOMENT)` <= 24h | `standalone/session_master_query.sql` (CTE `repeat_flag`) |
| 8 | Tiny channels produce noisy misroute rates | Aggregate views require >= 5,000 technical sessions per channel | `notebooks/02_executive_dashboard.ipynb` Step 8 query |
| 9 | Roman `IV/V/VI/VII` tags don't match the published mapping (`01_eda` Section 13 open items) | Currently mapped to `other_review` (excluded from misroute counting) | `standalone/session_master_query.sql` (CTE `tag_class`) - pending business confirmation |

## Open items for the data-science lead to confirm

1. Is `general_difficulty` (intent `I8`) genuinely a "technical" topic?
2. Treatment of `IV/V/VI/VII` tags — which are technical?
3. Should `Commercial (III)` count as a misroute for technical topics?
4. Is the technical-entity list right for **Business** sessions specifically?

Any change confirmed by the business is applied in
`standalone/session_master_query.sql`, and the dashboard automatically reflects
it (rebuild the `session_master` table and re-run the dashboard cells).
