USE ROLE DATA_ENGINEER;
USE SECONDARY ROLES NONE;
USE WAREHOUSE TRANSFORM_WH;
USE SCHEMA ECOM_DB.AUDIT;

CREATE TABLE IF NOT EXISTS DQ_RESULTS (
    checked_at     TIMESTAMP_TZ,
    dag_id         VARCHAR,
    run_id         VARCHAR,
    task_id        VARCHAR,
    check_name     VARCHAR,
    dataset        VARCHAR,
    severity       VARCHAR COMMENT 'error fails the Airflow task, warn only records',
    status         VARCHAR COMMENT 'pass or fail',
    checked_count  NUMBER(38,0) COMMENT 'Rows or objects the check looked at',
    failing_count  NUMBER(38,0) COMMENT 'Rows or objects that broke the rule; never record values',
    detail         VARCHAR,
    _loaded_at     TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'One row per data quality check per Airflow run: cross-batch key uniqueness, landing empty at rest, reconciliation and value checks. Append-only history.';

CREATE TABLE IF NOT EXISTS FRESHNESS_STATUS (
    checked_at      TIMESTAMP_TZ,
    dag_id          VARCHAR,
    run_id          VARCHAR,
    dataset         VARCHAR,
    contract        VARCHAR,
    sla_hours       NUMBER(6,2) COMMENT 'Maximum allowed age from the data contract',
    last_loaded_at  TIMESTAMP_TZ COMMENT 'Newest Bronze load time for the dataset; NULL if never loaded',
    age_hours       NUMBER(10,2),
    status          VARCHAR COMMENT 'fresh, stale or never_loaded',
    _loaded_at      TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'One row per dataset per freshness check, compared with the contract SLA. Append-only history; the latest row per dataset is the current status.';

CREATE TABLE IF NOT EXISTS LOAD_LOG (
    logged_at     TIMESTAMP_TZ,
    dag_id        VARCHAR,
    run_id        VARCHAR,
    feed          VARCHAR,
    contract      VARCHAR,
    batch_id      VARCHAR,
    s3_prefix     VARCHAR,
    action        VARCHAR COMMENT 'uploaded, or skipped when the batch was already decided',
    file_count    NUMBER(38,0),
    record_count  NUMBER(38,0),
    byte_count    NUMBER(38,0),
    _loaded_at    TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'One row per batch an Airflow producer DAG sent to landing or skipped. Producer-side ledger for reconciliation against validated and Bronze.';

SELECT OBJECT_AGG(table_name, column_count) AS audit_tables
FROM (
    SELECT table_name, COUNT(*)::VARIANT AS column_count
    FROM ECOM_DB.INFORMATION_SCHEMA.COLUMNS
    WHERE table_schema = 'AUDIT'
      AND table_name IN ('DQ_RESULTS', 'FRESHNESS_STATUS', 'LOAD_LOG', 'CONTRACT_VIOLATIONS')
    GROUP BY table_name
);