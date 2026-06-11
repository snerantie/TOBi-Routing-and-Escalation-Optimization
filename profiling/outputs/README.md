# Profiling outputs — drop your files here
<img width="835" height="407" alt="Error" src="https://github.com/user-attachments/assets/ccc4307a-5c82-4a61-9361-18ed79ae387c" />
<img width="241" height="387" alt="Session_master location" src="https://github.com/user-attachments/assets/92e98cd1-bf81-4cd4-967d-28fc3966c1f3" />




<img width="294" height="82" alt="d4b" src="https://github.com/user-attachments/assets/a9c08df2-5d23-4c57-b89b-50caf1695857" />
<img width="750" height="329" alt="d4a" src="https://github.com/user-attachments/assets/1a98ea0c-8921-462e-9234-ed6eb6c02794" />
<img width="330" height="260" alt="d3c" src="https://github.com/user-attachments/assets/4fcead42-708a-4bd0-9d99-47532e1aa475" />
<img width="330" height="138" alt="d3a" src="https://github.com/user-attachments/assets/4c7a85dc-dc78-4157-90cf-4b46ac19531f" />
<img width="291" height="81" alt="d2d" src="https://github.com/user-attachments/assets/ec6b855b-be34-4705-9ae3-738b88ae0993" />
<img width="325" height="132" alt="d1c" src="https://github.com/user-attachments/assets/fcdaef97-b160-4416-b13c-99ec9879fc7c" />
<img width="396" height="332" alt="d1b" src="https://github.com/user-attachments/assets/2eade5aa-87ec-4936-b2c6-395870af2af4" />






<img width="644" height="146" alt="d2a" src="https://github.com/user-attachments/assets/bd44de58-0406-48de-8c29-3e07fa706574" />
<img width="479" height="88" alt="d1a" src="https://github.com/user-attachments/assets/0134786b-c061-498d-bacd-62a17f52cd1e" />
<img width="418" height="86" alt="d8a" src="https://github.com/user-attachments/assets/01559e03-fc74-4d77-af9c-e010e0acbd19" />
<img width="533" height="331" alt="d4d" src="https://github.com/user-attachments/assets/d2ea4143-0460-4c70-93a5-2967699081dc" />




<img width="106" height="191" alt="I mappings" src="https://github.com/user-attachments/assets/733e3a75-3e3e-4c11-9453-1df15acfe607" />
<img width="87" height="313" alt="E Mappings" src="https://github.com/user-attachments/assets/dbf267b5-a1c5-42a0-9d81-168abb9b929e" />
<img width="112" height="97" alt="End Mappings" src="https://github.com/user-attachments/assets/40bf82c5-6046-451d-bc17-8edfa81fd110" />
<img width="729" height="287" alt="Mappings" src="https://github.com/user-attachments/assets/1dbb4d0d-2f77-490a-b7d1-de162988c45e" />

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
