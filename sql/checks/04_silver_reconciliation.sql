USE ROLE DATA_ENGINEER;
USE WAREHOUSE TRANSFORM_WH;

WITH ops_snap AS (
  SELECT b.* FROM ECOM_DB.SILVER.ORDERS o
  JOIN ECOM_DB.BRONZE.OPS_ORDERS b ON b.event_id = o.source_event_id
  WHERE o.source_system = 'ops'
),
m AS (
  SELECT 'orders_olist_rows' AS metric,
         (SELECT COUNT(*) FROM ECOM_DB.BRONZE.OLIST_ORDERS)::NUMBER(38,2) AS expected_value,
         (SELECT COUNT(*) FROM ECOM_DB.SILVER.ORDERS WHERE source_system = 'olist')::NUMBER(38,2) AS actual_value
  UNION ALL
  SELECT 'orders_ops_rows',
         (SELECT COUNT(DISTINCT order_id) FROM ECOM_DB.BRONZE.OPS_ORDERS),
         (SELECT COUNT(*) FROM ECOM_DB.SILVER.ORDERS WHERE source_system = 'ops')
  UNION ALL
  SELECT 'orders_unique_id',
         (SELECT COUNT(*) FROM ECOM_DB.SILVER.ORDERS),
         (SELECT COUNT(DISTINCT order_id) FROM ECOM_DB.SILVER.ORDERS)
  UNION ALL
  SELECT 'items_olist_rows',
         (SELECT COUNT(*) FROM ECOM_DB.BRONZE.OLIST_ORDER_ITEMS),
         (SELECT COUNT(*) FROM ECOM_DB.SILVER.ORDER_ITEMS WHERE source_system = 'olist')
  UNION ALL
  SELECT 'items_olist_price',
         (SELECT SUM(price) FROM ECOM_DB.BRONZE.OLIST_ORDER_ITEMS),
         (SELECT SUM(price) FROM ECOM_DB.SILVER.ORDER_ITEMS WHERE source_system = 'olist')
  UNION ALL
  SELECT 'items_olist_freight',
         (SELECT SUM(freight_value) FROM ECOM_DB.BRONZE.OLIST_ORDER_ITEMS),
         (SELECT SUM(freight_value) FROM ECOM_DB.SILVER.ORDER_ITEMS WHERE source_system = 'olist')
  UNION ALL
  SELECT 'items_ops_rows',
         (SELECT SUM(ARRAY_SIZE(items)) FROM ops_snap),
         (SELECT COUNT(*) FROM ECOM_DB.SILVER.ORDER_ITEMS WHERE source_system = 'ops')
  UNION ALL
  SELECT 'items_unique_key',
         (SELECT COUNT(*) FROM ECOM_DB.SILVER.ORDER_ITEMS),
         (SELECT COUNT(DISTINCT order_id, order_item_id) FROM ECOM_DB.SILVER.ORDER_ITEMS)
  UNION ALL
  SELECT 'payments_olist_value',
         (SELECT SUM(payment_value) FROM ECOM_DB.BRONZE.OLIST_ORDER_PAYMENTS),
         (SELECT SUM(payment_total) FROM ECOM_DB.SILVER.PAYMENTS WHERE source_system = 'olist')
  UNION ALL
  SELECT 'payments_olist_rows',
         (SELECT COUNT(*) FROM ECOM_DB.BRONZE.OLIST_ORDER_PAYMENTS),
         (SELECT SUM(payment_rows) FROM ECOM_DB.SILVER.PAYMENTS WHERE source_system = 'olist')
  UNION ALL
  SELECT 'payments_ops_rows',
         (SELECT SUM(ARRAY_SIZE(payments)) FROM ops_snap),
         (SELECT SUM(payment_rows) FROM ECOM_DB.SILVER.PAYMENTS WHERE source_system = 'ops')
  UNION ALL
  SELECT 'payments_one_row_per_order',
         (SELECT COUNT(*) FROM ECOM_DB.SILVER.PAYMENTS),
         (SELECT COUNT(DISTINCT order_id) FROM ECOM_DB.SILVER.PAYMENTS)
  UNION ALL
  SELECT 'items_price_after_payment_join',
         (SELECT SUM(price) FROM ECOM_DB.SILVER.ORDER_ITEMS),
         (SELECT SUM(i.price) FROM ECOM_DB.SILVER.ORDER_ITEMS i LEFT JOIN ECOM_DB.SILVER.PAYMENTS p ON p.order_id = i.order_id)
  UNION ALL
  SELECT 'customers_olist_rows',
         (SELECT COUNT(*) FROM ECOM_DB.BRONZE.OLIST_CUSTOMERS),
         (SELECT COUNT(*) FROM ECOM_DB.SILVER.CUSTOMERS WHERE source_system = 'olist')
  UNION ALL
  SELECT 'customers_ops_rows',
         (SELECT COUNT(DISTINCT customer_id) FROM ECOM_DB.BRONZE.OPS_ORDERS),
         (SELECT COUNT(*) FROM ECOM_DB.SILVER.CUSTOMERS WHERE source_system = 'ops')
  UNION ALL
  SELECT 'products_rows',
         (SELECT COUNT(*) FROM ECOM_DB.BRONZE.OLIST_PRODUCTS),
         (SELECT COUNT(*) FROM ECOM_DB.SILVER.PRODUCTS)
)
SELECT OBJECT_CONSTRUCT(
  'metrics', COUNT(*),
  'all_match', BOOLAND_AGG(expected_value = actual_value),
  'mismatches', ARRAY_AGG(IFF(expected_value = actual_value, NULL,
                OBJECT_CONSTRUCT('metric', metric, 'expected', TO_VARCHAR(expected_value), 'actual', TO_VARCHAR(actual_value))))
) AS result
FROM m;