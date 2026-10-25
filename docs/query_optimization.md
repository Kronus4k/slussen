# Query optimization: warehouse generation on the Gold workload

Snowflake offers two generations of standard warehouses. Gen2 runs on newer hardware and is faster per query, but on AWS it bills about 1.35 times the credits per second of a Gen1 warehouse of the same size. New accounts default to Gen2. This platform runs every warehouse as an X-Small Gen1 (`GENERATION = '1'`). This page records the measurement behind keeping that choice.

## Method

Two temporary warehouses, identical except for the generation:

| Setting | BENCH_GEN1_WH | BENCH_GEN2_WH |
| --- | --- | --- |
| Size | X-Small | X-Small |
| Generation | 1 | 2 |
| Auto-suspend | 60 s | 60 s |
| State before the run | suspended, never used | suspended, never used |

Both warehouses started cold, so neither had data in its local disk cache. The result cache was switched off for the session (`USE_CACHED_RESULT = FALSE`), so every repeat really computed. Every query carried a `QUERY_TAG` and the timings were read from `INFORMATION_SCHEMA.QUERY_HISTORY_BY_USER`.

Two queries, each run once cold and twice warm on each warehouse:

- **Q1, transform:** the Gold GMV logic on Silver. Orders joined to items, regions and payments, GMV per day and market, then a 7-day moving average. About 100k orders and 113k items, 25.3 MB scanned.
- **Q2, scan and aggregate:** about 1M rows of `BRONZE.OLIST_GEOLOCATION`, distinct zip codes and the median latitude per state. 19.5 MB scanned.

The comparison uses execution time. Compilation runs in the cloud services layer, is the same for both generations, and varied between 0.2 s and 2.2 s from run to run, which would only add noise.

## Results

Execution time in milliseconds:

| Query | Gen1 cold | Gen1 warm (avg) | Gen2 cold | Gen2 warm (avg) | Gen2 / Gen1 warm |
| --- | --- | --- | --- | --- | --- |
| Q1 transform | 826 | 197 | 569 | 147 | 0.75 |
| Q2 scan and aggregate | 620 | 315 | 487 | 216 | 0.69 |

What the numbers say:

1. **Gen2 is faster:** 25 to 31 percent less execution time on warm runs, and 21 to 31 percent on cold runs.
2. **The local disk cache matters more than the generation.** A warm Gen1 run of Q1 took 197 ms against 826 ms cold, a factor of about 4.
3. **Every query finished in under one second of execution.** Total elapsed time, including compilation, stayed between 0.4 s and 2.9 s.

## Cost reading

A warehouse is billed per second while it runs, with a minimum of 60 seconds each time it resumes. On this platform a warehouse resumes for a few seconds of work at a time: a producer's load log insert, a check run, a Dynamic Table refresh every 12 hours. Each resume is therefore billed at the 60-second minimum, whatever the generation.

- At the 60-second minimum, Gen2 costs 1.35 times as much for the same work, because it cannot finish in less than the minimum.
- Gen2 becomes cheaper only when a workload runs well past the minimum and the speed-up beats the price factor. The break-even is an execution time ratio of 1 / 1.35 = 0.74. Q2 (0.69) would be slightly cheaper on Gen2 if it ran for minutes. Q1 (0.75) would cost the same.

## Decision

Keep all warehouses on X-Small Gen1. At the current data volume every workload fits inside the 60-second billing minimum, so Gen2 would raise the cost by 35 percent for speed nobody notices.

Revisit this when a workload runs for minutes at a time, for example a full Gold rebuild on much larger data, or a dashboard with many concurrent users. In that case, rerun the benchmark on that workload and compare the execution time ratio with 0.74.

## Limits of this measurement

- Two warm runs per query: enough to show the direction, not a statistical result.
- Data volumes of 20 to 25 MB. Larger scans may favour Gen2 more.
- One region (AWS eu-north-1) and one size (X-Small).

## Reproduce

The files are in `sql/benchmarks/`, run in this order:

1. `01_warehouse_generation_setup.sql`: creates the two warehouses (Run All).
2. `02_warehouse_generation_run.sql`: the 12 tagged queries (Run All).
3. `03_warehouse_generation_results.sql`: reads the timings from query history.
4. `04_warehouse_generation_cleanup.sql`: drops both warehouses.

The whole run costs about two warehouse resumes at the 60-second minimum, well under 0.1 credits.
