WITH people AS (
    SELECT DISTINCT customer_unique_id FROM ECOM_DB.BRONZE.OPS_ORDERS
), history AS (
    SELECT DISTINCT customer_unique_id FROM ECOM_DB.SILVER.CUSTOMERS_HISTORY
)
SELECT COUNT(*) AS checked_count, COUNT_IF(h.customer_unique_id IS NULL) AS failing_count
FROM people p LEFT JOIN history h ON h.customer_unique_id = p.customer_unique_id