\# Lake query costs: CSV vs Parquet



The same questions asked in Amazon Athena of the raw Olist orders CSV and of the contract-validated Parquet written by the gate. Athena bills by bytes scanned ($5 per TB, minimum 10 MB per query), so scanned bytes are the cost driver.



\## Method



\- Raw CSV: `landing/olist/orders/olist\_orders\_dataset.csv`, 99,441 rows, read through a temporary `OpenCSVSerde` table (all columns as text).

\- Parquet: `validated/olist/orders/dt=2026-10-20/…`, the same 99,441 rows, read through the table generated from the `olist\_orders` contract (Snappy-compressed, typed columns, partition projection on `dt`).

\- Scanned bytes from Athena's own query statistics (`DataScannedInBytes`), via `scripts/athena/run\_sql.py sql/athena/03\_scan\_measurement.sql`.



\## Results



| Question | CSV scanned | Parquet scanned | Result (identical in both) |

| --- | ---: | ---: | --- |

| Count all orders | 17.65 MB | 0.00 MB | 99,441 |

| Orders by status, top 3 | 17.65 MB | 0.01 MB | delivered 96,478 · shipped 1,107 · canceled 625 |

| Orders purchased in 2018 | 17.65 MB | 1.69 MB | 54,011 |



\## Why



\- CSV has no columns on disk, only lines of text, so every question reads the whole file.

\- Parquet stores each column separately and keeps row counts and min/max statistics in the file footer. A count reads only the footer; a one-column question reads only that column, which is small when values repeat (dictionary encoding).

\- File size alone shrank only 1.7× for this table (random 32-character ids compress poorly); the large saving comes from reading only the columns a query needs.



\## At scale



At this size every query costs the 10 MB minimum. On 1 TB of history, the status question would scan about 1 TB as CSV ($5) and well under 1 GB as Parquet (under $0.01).

