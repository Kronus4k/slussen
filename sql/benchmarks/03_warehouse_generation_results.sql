USE ROLE PLATFORM_ADMIN;
USE WAREHOUSE TRANSFORM_WH;

SELECT OBJECT_CONSTRUCT(
  'queries', (SELECT ARRAY_AGG(OBJECT_CONSTRUCT(
                 'tag', query_tag,
                 'total_ms', total_elapsed_time,
                 'exec_ms', execution_time,
                 'compile_ms', compilation_time,
                 'queued_ms', queued_provisioning_time + queued_overload_time,
                 'mb_scanned', ROUND(bytes_scanned / 1048576, 1)))
               WITHIN GROUP (ORDER BY start_time)
              FROM TABLE(ECOM_DB.INFORMATION_SCHEMA.QUERY_HISTORY_BY_USER(RESULT_LIMIT => 1000))
              WHERE query_tag LIKE 'bench:%' AND query_type = 'SELECT' AND start_time > DATEADD('hour', -2, CURRENT_TIMESTAMP())),
  'credits', (SELECT OBJECT_AGG(warehouse_name, TO_VARIANT(TO_VARCHAR(c))) FROM (
                SELECT warehouse_name, SUM(credits_used) AS c
                FROM TABLE(ECOM_DB.INFORMATION_SCHEMA.WAREHOUSE_METERING_HISTORY(DATEADD('hour', -2, CURRENT_TIMESTAMP())))
                WHERE warehouse_name LIKE 'BENCH_GEN%'
                GROUP BY warehouse_name))
) AS result;

USE ROLE DATA_ENGINEER;