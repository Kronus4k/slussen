SELECT 'olist_orders' AS table_name, count(*) AS row_count,
       date_format(max(order_purchase_timestamp), '%Y-%m-%d %H:%i:%s') AS value_check
FROM slussen_lake.olist_orders WHERE dt = '2026-10-20'
UNION ALL
SELECT 'olist_order_items', count(*), CAST(sum(price) AS varchar)
FROM slussen_lake.olist_order_items WHERE dt = '2026-10-20'
UNION ALL
SELECT 'olist_order_payments', count(*), CAST(sum(payment_value) AS varchar)
FROM slussen_lake.olist_order_payments WHERE dt = '2026-10-20'
UNION ALL
SELECT 'olist_customers', count(*), CAST(count_if(customer_zip_code_prefix LIKE '0%') AS varchar)
FROM slussen_lake.olist_customers WHERE dt = '2026-10-20'
UNION ALL
SELECT 'olist_geolocation', count(*), CAST(sum(geolocation_lat) AS varchar)
FROM slussen_lake.olist_geolocation WHERE dt = '2026-10-20'
UNION ALL
SELECT 'ops_orders', count(*), CAST(count(DISTINCT event_id) AS varchar)
FROM slussen_lake.ops_orders WHERE dt >= '2026-10-17'
ORDER BY 1;