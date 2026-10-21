USE SECONDARY ROLES NONE;
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE TRANSFORM_WH;
WITH by_service AS (
    SELECT service_type, ROUND(SUM(credits_used), 4) AS credits
    FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_HISTORY
    WHERE start_time >= '2026-10-12'::TIMESTAMP_LTZ
    GROUP BY service_type
),
pipes AS (
    SELECT ROUND(SUM(credits_used), 6) AS credits,
           SUM(bytes_inserted) AS bytes,
           SUM(files_inserted) AS files
    FROM SNOWFLAKE.ACCOUNT_USAGE.PIPE_USAGE_HISTORY
    WHERE start_time >= '2026-10-12'::TIMESTAMP_LTZ
)
SELECT OBJECT_CONSTRUCT(
    'credits_by_service', (SELECT OBJECT_AGG(service_type, credits::VARIANT) FROM by_service),
    'pipe_credits', p.credits,
    'pipe_gb_inserted', ROUND(p.bytes / POWER(1000, 3), 4)::NUMBER(12, 4),
    'pipe_files', p.files::INTEGER,
    'pipe_credits_at_list_rate', ROUND(p.bytes / POWER(1000, 3) * 0.0037, 6)::NUMBER(12, 6)
) AS serverless_cost
FROM pipes p;
USE ROLE DATA_ENGINEER;