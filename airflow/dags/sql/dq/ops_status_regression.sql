WITH ranked AS (
    SELECT
        order_id,
        CASE order_status WHEN 'created' THEN 1 WHEN 'approved' THEN 2 WHEN 'shipped' THEN 3 WHEN 'delivered' THEN 4 END AS status_rank,
        MAX(CASE order_status WHEN 'created' THEN 1 WHEN 'approved' THEN 2 WHEN 'shipped' THEN 3 WHEN 'delivered' THEN 4 END) OVER (PARTITION BY order_id) AS max_rank,
        ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY event_ts DESC, event_id DESC) AS rn
    FROM ECOM_DB.BRONZE.OPS_ORDERS
)
SELECT COUNT_IF(rn = 1) AS checked_count, COUNT_IF(rn = 1 AND status_rank < max_rank) AS failing_count
FROM ranked