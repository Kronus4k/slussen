# Data contracts

Each source feed has one YAML contract, agreed between the producing team and the data platform. Files that break their contract never reach Snowflake: they are moved to `quarantine/`, logged in `AUDIT.CONTRACT_VIOLATIONS` and the owner is alerted.

| Contract | Owner | Format | Cadence |
| --- | --- | --- | --- |
| `ops_orders` | Operations | JSON Lines | Every 4 hours, data no older than 5 hours |
| `finance_settlements` | Finance | Parquet | Weekly, by Monday 06:00 UTC |
| `olist_orders` | Data platform | CSV | One-off backfill |
| `olist_customers` | Data platform | CSV | One-off backfill |
| `olist_order_items` | Data platform | CSV | One-off backfill |
| `olist_order_payments` | Data platform | CSV | One-off backfill |
| `olist_order_reviews` | Data platform | CSV | One-off backfill |
| `olist_products` | Data platform | CSV | One-off backfill |
| `olist_sellers` | Data platform | CSV | One-off backfill |
| `olist_product_category_name_translation` | Data platform | CSV | One-off backfill |
| `olist_geolocation` | Data platform | CSV | One-off backfill |

The Olist contracts cover the historical seed data, one contract per source table. Their keys come from profiling the source: `order_reviews` is keyed on `review_id` plus `order_id` because `review_id` alone repeats across orders.

## Validation rules

| Change in a file | Classification | Action |
| --- | --- | --- |
| Extra unknown column | Non-breaking | Load agreed columns only, log a warning |
| Missing column | Breaking | Quarantine, alert |
| Type change | Breaking | Quarantine, alert |
| Null in a required field | Breaking | Quarantine, alert |
| Duplicate primary key within file | Breaking | Quarantine, alert |
| Unreadable file (invalid JSON, not Parquet, not UTF-8, CSV row with the wrong number of fields) | Breaking | Quarantine, alert |
| `_SUCCESS` marker without data files | Breaking | Quarantine, alert |
| No `_SUCCESS` marker yet | Incomplete batch | Wait, do not validate |
| Files uploaded again into a batch that is already decided | Duplicate batch (warning) | Move as sent to `quarantine/<feed>/_duplicates/`, log a warning, alert |
| Repeated event for a batch whose files are already processed | Harmless | Skip, nothing changes |

A batch is all-or-nothing: one breaking finding in any file quarantines the whole batch. Findings are capped at 10 rows per rule and column per file and never contain record values. When the cap drops findings, one `info` row per rule and column records how many were suppressed (`suppressed_count`), so breaking + warning + suppressed always equals everything the validator found.

## Re-sending data

A batch id is used once. After a batch is decided (validated or quarantined), files uploaded again under the same batch id are not processed: the gate moves them as sent to `quarantine/<feed>/_duplicates/dt=…/batch=…/received=<timestamp>/`, records a `duplicate_batch` warning in its own audit file and alerts the owner. The original decision is never overwritten.

Corrected or complete data is re-sent as a new batch with a new batch id. If a validated batch later turns out to be wrong, its data is removed from `validated/` and from Bronze in the same change, and the corrected data arrives as a new batch.

## Versioning

| Bump | When | Example |
| --- | --- | --- |
| Major | Breaking: column removed, renamed or retyped, nullable to required | 1.x.x → 2.0.0 |
| Minor | Additive: new nullable column | 1.0.x → 1.1.0 |
| Patch | Descriptions, owner contact | 1.0.0 → 1.0.1 |

A major version is agreed with the owning team before files in the new shape land.

## Logical types

| Type | Meaning |
| --- | --- |
| `string` | Text. Zip prefixes are strings so leading zeros survive. |
| `integer` | Whole number. |
| `decimal(p,s)` | Exact number with at most `p` digits, `s` of them after the point. Money is `decimal(10,2)`. |
| `date` | Calendar date, `YYYY-MM-DD`. |
| `timestamp` | Point in time in UTC, with an explicit zone. |
| `timestamp_ntz` | Date and time without a zone (`YYYY-MM-DD HH:MM:SS`), for sources that do not state one. The zone is applied in Silver, not at the gate. |
| `boolean` | True or false. |
| `array` | List of objects, described by `fields`. |

Each reader maps these to its format. JSON values are checked against the logical type. CSV values arrive as text and are converted using the contract: empty fields become null, and a value that does not convert stays text so the type check reports it. Parquet columns come back with the file's own types. Validated files are written as Parquet with types derived from the contract: `timestamp` with a UTC zone, `timestamp_ntz` without one.

## Contracts without a key

`primary_key` is required. A contract may declare it empty (`primary_key: []`) when the source has no natural key; the duplicate-key rule is then skipped and rows land as sent. This is used only for `olist_geolocation`, where about 262,000 of 1,000,163 rows are exact duplicates. Deduplication, if that table is ever modelled, belongs in Silver.

## Scope

Contracts check shape: columns, types, nullability, uniqueness, completeness. Value rules (allowed status values, non-negative amounts, `net = gross - fee`) are data quality checks in `AUDIT.DQ_RESULTS`.
