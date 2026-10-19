USE ROLE DATA_ENGINEER;
USE SECONDARY ROLES NONE;
USE WAREHOUSE LOAD_WH;
USE SCHEMA ECOM_DB.AUDIT;

CREATE PIPE IF NOT EXISTS PIPE_CONTRACT_VIOLATIONS
    AUTO_INGEST = TRUE
    COMMENT = 'Loads contract gate findings from audit/contract_violations/ into CONTRACT_VIOLATIONS.'
AS
COPY INTO ECOM_DB.AUDIT.CONTRACT_VIOLATIONS (
    detected_at,
    contract,
    contract_version,
    batch,
    file_key,
    batch_status,
    rule,
    severity,
    column_name,
    row_number,
    detail,
    suppressed_count,
    _file_name,
    _file_row_number,
    _loaded_at
)
FROM (
    SELECT
        $1:detected_at::TIMESTAMP_TZ,
        $1:contract::VARCHAR,
        $1:contract_version::VARCHAR,
        $1:batch::VARCHAR,
        $1:file_key::VARCHAR,
        $1:batch_status::VARCHAR,
        $1:rule::VARCHAR,
        $1:severity::VARCHAR,
        $1:column_name::VARCHAR,
        $1:row_number::NUMBER(38,0),
        $1:detail::VARCHAR,
        $1:suppressed_count::NUMBER(38,0),
        METADATA$FILENAME,
        METADATA$FILE_ROW_NUMBER,
        CURRENT_TIMESTAMP()
    FROM @ECOM_DB.AUDIT.STG_CONTRACT_VIOLATIONS
)
PATTERN = '.*[.]jsonl'
FILE_FORMAT = (FORMAT_NAME = 'ECOM_DB.AUDIT.FF_JSONL');

ALTER PIPE PIPE_CONTRACT_VIOLATIONS REFRESH MODIFIED_AFTER = '2026-10-18T00:00:00Z';