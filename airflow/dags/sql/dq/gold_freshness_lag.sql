WITH b AS (
    SELECT MAX(order_purchase_ts) AS max_ts FROM ECOM_DB.BRONZE.OPS_ORDERS
), g AS (
    SELECT MAX(order_purchase_ts) AS max_ts FROM ECOM_DB.GOLD.FCT_ORDERS WHERE source_system = 'ops'
)
SELECT 1 AS checked_count,
       IFF(g.max_ts IS NULL OR DATEDIFF('minute', g.max_ts, b.max_ts) > 16 * 60, 1, 0) AS failing_count
FROM b CROSS JOIN g