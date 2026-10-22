WITH items AS (
    SELECT i.value:product_id::STRING AS product_id
    FROM ECOM_DB.BRONZE.OPS_ORDERS o, LATERAL FLATTEN(input => o.items) i
    WHERE o._loaded_at >= DATEADD(hour, -24, CURRENT_TIMESTAMP())
), products AS (
    SELECT DISTINCT product_id FROM ECOM_DB.BRONZE.OLIST_PRODUCTS
)
SELECT COUNT(*) AS checked_count, COUNT_IF(p.product_id IS NULL) AS failing_count
FROM items LEFT JOIN products p ON p.product_id = items.product_id
