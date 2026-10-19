\# Contract gate capacity



How large a batch the contract gate Lambda can validate, and why batches over 50 MB are routed to ECS Fargate.



\## Method



\- Script: `scripts/capacity/gate\_capacity.py`.

\- Synthetic `ops\_orders` batches from the generator, clean data, one JSON Lines file per batch (about 930 bytes per record).

\- Data uploaded without a `\_SUCCESS` marker and the Lambda invoked directly with the same `{bucket, key}` payload Step Functions sends, so batches above the routing threshold can be measured and no alerts fire.

\- One discarded warm-up run; all measured runs are warm starts. Client retries disabled so no batch is validated twice.

\- Every test batch is deleted from `landing/`, `validated/`, `quarantine/` and `audit/` after its run.

\- Function: container image, x86\_64, 1,024 MB memory, 300 s timeout.



\## Results



| Records | Batch MB | Status | Duration s | Max memory MB |

| ---: | ---: | --- | ---: | ---: |

| 1,000 | 0.9 | validated | 0.44 | 161 |

| 10,000 | 9.3 | validated | 1.79 | 242 |

| 25,000 | 23.3 | validated | 4.40 | 352 |

| 50,000 | 46.5 | validated | 8.85 | 548 |

| 100,000 | 93.0 | validated | 18.19 | 911 |

| 150,000 | 139.5 | timed out | 300.00 | 1,024 |



\## Findings



\- Memory grows linearly: about 160 MB base plus 8.2 MB per MB of input. Parsed records are Python objects (dicts, strings, `Decimal`) at roughly four times the size of the JSON text, and the gate holds the raw bytes, the parsed records and the Arrow/Parquet output at the same time.

\- Duration grows linearly at about 0.19 s per MB, far below the 300 s timeout.

\- The limit is memory, at about 105 MB of input. At the cap the function did not raise an out-of-memory error: it slowed down until the 300 s timeout ended the run.



\## Decision



Batches over 50 MB (50,000,000 bytes, `RouteBySize` in the state machine) go to ECS Fargate running the same image; the Lambda stays at 1,024 MB. At 50 MB the expected peak is about 570 MB, about 55% of the function's memory.



Rejected: raising Lambda memory (higher cost for every batch, little gain for single-threaded Python) and keeping the 100 MB placeholder (above the measured limit).



\## Next improvement



Validate files in chunks with Arrow compute instead of holding whole files as Python objects. Columnar buffers cut the memory multiplier, and chunking makes memory nearly independent of file size; only the set of primary keys seen still grows.

