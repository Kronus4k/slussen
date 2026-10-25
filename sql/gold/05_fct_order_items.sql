USE ROLE DATA_ENGINEER;

CREATE OR REPLACE DYNAMIC TABLE ECOM_DB.GOLD.FCT_ORDER_ITEMS
  TARGET_LAG = '12 hours'
  WAREHOUSE = TRANSFORM_WH
  REFRESH_MODE = AUTO
AS
SELECT
  i.order_id,
  i.order_item_id,
  f.order_date_local,
  f.market_code,
  f.customer_unique_id,
  f.order_status,
  f.is_gmv_order,
  IFF(p.product_id IS NULL, 'unknown', i.product_id) AS product_id,
  i.seller_id,
  i.price::NUMBER(12,2) AS price,
  i.freight_value::NUMBER(12,2) AS freight_value,
  (i.price + i.freight_value)::NUMBER(12,2) AS item_value,
  IFF(f.is_gmv_order, i.price + i.freight_value, 0)::NUMBER(12,2) AS gmv
FROM ECOM_DB.SILVER.ORDER_ITEMS i
JOIN ECOM_DB.GOLD.FCT_ORDERS f ON f.order_id = i.order_id
LEFT JOIN ECOM_DB.SILVER.PRODUCTS p ON p.product_id = i.product_id;