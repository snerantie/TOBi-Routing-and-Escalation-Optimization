# Profiling outputs — drop your files here
<img width="106" height="191" alt="I mappings" src="https://github.com/user-attachments/assets/733e3a75-3e3e-4c11-9453-1df15acfe607" />
<img width="87" height="313" alt="E Mappings" src="https://github.com/user-attachments/assets/dbf267b5-a1c5-42a0-9d81-168abb9b929e" />
<img width="112" height="97" alt="End Mappings" src="https://github.com/user-attachments/assets/40bf82c5-6046-451d-bc17-8edfa81fd110" />
<img width="729" height="287" alt="Mappings" src="https://github.com/user-attachments/assets/1dbb4d0d-2f77-490a-b7d1-de162988c45e" />

<img width="652" height="151" alt="d2a" src="https://github.com/user-attachments/assets/cc23aaf4-e680-425b-a8fa-6555b98db026" />
<img width="463" height="85" alt="d1a" src="https://github.com/user-attachments/assets/169f3674-c475-491e-8185-2e9a72ac406f" />
<img width="291" height="323" alt="d4d" src="https://github.com/user-attachments/assets/09a5d475-bbea-4faf-8cea-78a156c125a7" />
<img width="312" height="324" alt="d4d (2)" src="https://github.com/user-attachments/assets/aa891c82-c995-40dc-880c-676f3b6c44c7" />
<img width="291" height="321" alt="d4d (3)" src="https://github.com/user-attachments/assets/be77ac42-9317-4b09-b4dd-25f2c364903d" />
<img width="465" height="88" alt="d8a" src="https://github.com/user-attachments/assets/782f56c2-0f7e-48cd-b3c4-bcf5c698ab28" />

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
