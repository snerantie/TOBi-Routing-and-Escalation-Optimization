# Profiling outputs — drop your files here
<img width="320" height="300" alt="image0" src="https://github.com/user-attachments/assets/ddfcf2c6-e615-42e5-ab2c-a600b9c41758" />
<img width="320" height="180" alt="image1" src="https://github.com/user-attachments/assets/be77a764-0034-4fb6-821b-d34bc137c6a5" />
<img width="240" height="320" alt="image2" src="https://github.com/user-attachments/assets/184d47fb-4f42-4ffb-81b6-517be73f0cf7" />
<img width="274" height="320" alt="image3" src="https://github.com/user-attachments/assets/f80501a5-4d5d-4271-bac6-6038f3808960" />
<img width="320" height="186" alt="image4" src="https://github.com/user-attachments/assets/28ca6678-049c-4dd6-a98c-8fdae4126c27" />
<img width="262" height="320" alt="image5" src="https://github.com/user-attachments/assets/2e5570fc-5ee4-4f3f-8f29-9c8cf769ad34" />
<img width="246" height="320" alt="image7" src="https://github.com/user-attachments/assets/21be9b9e-ce14-41ad-8421-758b970dd9c5" />
<img width="320" height="286" alt="image8" src="https://github.com/user-attachments/assets/da4a22db-270d-41dc-9340-eb32244f28db" />
<img width="296" height="320" alt="image9" src="https://github.com/user-attachments/assets/9d640bae-7658-4487-b036-5acef633efe1" />
<img width="238" height="320" alt="image10" src="https://github.com/user-attachments/assets/e8deb857-d40c-4765-a23d-bec199fa831e" />
<img width="306" height="320" alt="image11" src="https://github.com/user-attachments/assets/aedd3a01-e81c-49a5-92d7-0d8236af019d" />
<img width="308" height="320" alt="image12" src="https://github.com/user-attachments/assets/30029e48-e5d2-4535-b34f-d8f278170efd" />
<img width="320" height="262" alt="image13" src="https://github.com/user-attachments/assets/f697ee1e-a62c-4d43-99fd-c8a093f23283" />


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
