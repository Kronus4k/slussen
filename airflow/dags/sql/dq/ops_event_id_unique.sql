SELECT COUNT(*) AS checked_count, COUNT_IF(files > 1) AS failing_count
FROM (
    SELECT event_id, COUNT(DISTINCT _file_name) AS files
    FROM ECOM_DB.BRONZE.OPS_ORDERS
    GROUP BY event_id
)