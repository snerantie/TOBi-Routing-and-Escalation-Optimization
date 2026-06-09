# Profiling outputs — drop your files here

Upload your BigQuery profiling results into this folder (`profiling/outputs/`) so
they can be read and used to validate the classification logic.

## What to upload (priority order)
1. **`p3a` — distinct `T_` routing destinations** (names + counts). Most important.
2. **`p2e` — distinct `IS_FUNCTIONAL` values**.
3. **`p2f` — distinct `CONFIDENCE_LEVEL` values**.
4. Nice-to-have: `p3b` (`R_` tokens), `p3c` (`M_` tokens), `p2c` (`service_type`),
   `p2d` (`HOTLINE_REASON_CODE`).

## Accepted formats
- **CSV** (BigQuery: `Save results -> CSV (local file)`) — most reliable.
- **Images** (`.png` / `.jpg`) — screenshots of the result tables work too.

## After uploading
Just say which files you added (e.g. "uploaded p3a_transfers.csv"). The classification
logic in the `standalone/` pipeline (the queue `CASE` and the technical-topic
`REGEXP_CONTAINS`) will be tuned to match, and the standalone files regenerated.

> This folder is for analysis input only.
