WITH paid AS (
    SELECT DISTINCT order_id FROM ECOM_DB.BRONZE.OLIST_ORDER_PAYMENTS
)
SELECT COUNT(*) AS checked_count, COUNT_IF(p.order_id IS NULL) AS failing_count
FROM ECOM_DB.BRONZE.OLIST_ORDERS o LEFT JOIN paid p ON p.order_id = o.order_id