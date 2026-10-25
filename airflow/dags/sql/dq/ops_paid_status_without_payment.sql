WITH latest AS (
    SELECT order_status, payments
    FROM ECOM_DB.BRONZE.OPS_ORDERS
    QUALIFY ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY event_ts DESC, event_id DESC) = 1
)
SELECT COUNT(*) AS checked_count,
       COUNT_IF(order_status IN ('approved', 'shipped', 'delivered') AND payments IS NULL) AS failing_count
FROM latest