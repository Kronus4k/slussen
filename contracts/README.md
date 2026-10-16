# Data contracts

Each source feed has one YAML contract, agreed between the producing team and the data platform. Files that break their contract never reach Snowflake: they are moved to `quarantine/`, logged in `AUDIT.CONTRACT_VIOLATIONS` and the owner is alerted.

| Contract | Owner | Format | Cadence |
| --- | --- | --- | --- |
| `ops_orders` | Operations | JSON Lines | Every 4 hours, data no older than 5 hours |
| `finance_settlements` | Finance | Parquet | Weekly, by Monday 06:00 UTC |

## Validation rules

| Change in a file | Classification | Action |
| --- | --- | --- |
| Extra unknown column | Non-breaking | Load agreed columns only, log a warning |
| Missing column | Breaking | Quarantine, alert |
| Type change | Breaking | Quarantine, alert |
| Null in a required field | Breaking | Quarantine, alert |
| Duplicate primary key within file | Breaking | Quarantine, alert |
| No `_SUCCESS` marker yet | Incomplete batch | Wait, do not validate |

## Versioning

| Bump | When | Example |
| --- | --- | --- |
| Major | Breaking: column removed, renamed or retyped, nullable to required | 1.x.x → 2.0.0 |
| Minor | Additive: new nullable column | 1.0.x → 1.1.0 |
| Patch | Descriptions, owner contact | 1.0.0 → 1.0.1 |

A major version is agreed with the owning team before files in the new shape land.

## Logical types

`string`, `integer`, `decimal(p,s)`, `date`, `timestamp` (UTC), `boolean`, `array` (with `fields`). Each reader maps these to its format: JSON values are checked against the logical type, Parquet columns against the file's Arrow schema.

## Scope

Contracts check shape: columns, types, nullability, uniqueness, completeness. Value rules (allowed status values, non-negative amounts, `net = gross - fee`) are data quality checks in `AUDIT.DQ_RESULTS`.