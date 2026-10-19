USE ROLE DATA_ENGINEER;
USE SECONDARY ROLES NONE;
USE WAREHOUSE LOAD_WH;
USE SCHEMA ECOM_DB.AUDIT;

ALTER TABLE IF EXISTS CONTRACT_VIOLATIONS
    ADD COLUMN IF NOT EXISTS suppressed_count NUMBER(38,0)
    COMMENT 'Findings dropped by the cap of 10 per rule and column; set on info summary rows, NULL on real findings';

ALTER TABLE IF EXISTS CONTRACT_VIOLATIONS SET
    COMMENT = 'One row per data contract finding from the S3 contract gate: breaking violations that quarantined a batch, warnings on accepted batches, and info rows counting findings suppressed by the cap. Loaded from s3 audit/contract_violations/.';

SELECT COUNT(*) AS rows_total,
       COUNT(suppressed_count) AS rows_with_count,
       (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
         WHERE TABLE_SCHEMA = 'AUDIT' AND TABLE_NAME = 'CONTRACT_VIOLATIONS'
           AND COLUMN_NAME = 'SUPPRESSED_COUNT') AS column_exists
FROM CONTRACT_VIOLATIONS;