USE ROLE DATA_ENGINEER;
USE SECONDARY ROLES NONE;
USE WAREHOUSE LOAD_WH;
USE SCHEMA ECOM_DB.AUDIT;

COPY INTO CONTRACT_VIOLATIONS (
    detected_at, contract, contract_version, batch, file_key, batch_status,
    rule, severity, column_name, row_number, detail, _file_name, _file_row_number
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
        $1:row_number::NUMBER,
        $1:detail::VARCHAR,
        METADATA$FILENAME,
        METADATA$FILE_ROW_NUMBER
    FROM @STG_CONTRACT_VIOLATIONS
)
PATTERN = '.*violations[.]jsonl'
ON_ERROR = ABORT_STATEMENT;

SELECT batch, batch_status, rule, severity, column_name, COUNT(*) AS findings
FROM CONTRACT_VIOLATIONS
GROUP BY batch, batch_status, rule, severity, column_name
ORDER BY batch, severity, rule;