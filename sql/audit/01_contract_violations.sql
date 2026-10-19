USE ROLE DATA_ENGINEER;
USE SECONDARY ROLES NONE;
USE WAREHOUSE TRANSFORM_WH;
USE SCHEMA ECOM_DB.AUDIT;

CREATE TABLE IF NOT EXISTS CONTRACT_VIOLATIONS (
    detected_at       TIMESTAMP_TZ,
    contract          VARCHAR,
    contract_version  VARCHAR,
    batch             VARCHAR,
    file_key          VARCHAR,
    batch_status      VARCHAR,
    rule              VARCHAR,
    severity          VARCHAR,
    column_name       VARCHAR,
    row_number        NUMBER,
    detail            VARCHAR,
    _file_name        VARCHAR,
    _file_row_number  NUMBER,
    _loaded_at        TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
    suppressed_count  NUMBER(38,0) COMMENT 'Findings dropped by the cap of 10 per rule and column; set on info summary rows, NULL on real findings'
)
COMMENT = 'One row per data contract finding from the S3 contract gate: breaking violations that quarantined a batch, warnings on accepted batches, and info rows counting findings suppressed by the cap. Loaded from s3 audit/contract_violations/.';

CREATE FILE FORMAT IF NOT EXISTS FF_JSONL
    TYPE = JSON
    STRIP_OUTER_ARRAY = FALSE;

CREATE STAGE IF NOT EXISTS STG_CONTRACT_VIOLATIONS
    URL = 's3://slussen-lake-qwer/audit/contract_violations/'
    STORAGE_INTEGRATION = SLUSSEN_S3_INT
    FILE_FORMAT = FF_JSONL;

LIST @STG_CONTRACT_VIOLATIONS;