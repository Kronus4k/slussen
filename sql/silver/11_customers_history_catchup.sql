USE ROLE DATA_ENGINEER;
USE WAREHOUSE TRANSFORM_WH;

ALTER DYNAMIC TABLE ECOM_DB.SILVER.ORDERS REFRESH;

ALTER DYNAMIC TABLE ECOM_DB.SILVER.CUSTOMERS REFRESH;

INSERT INTO ECOM_DB.SILVER.CUSTOMERS_HISTORY (
  customer_unique_id, customer_zip_code_prefix, customer_city, customer_state, region_name, market_code,
  address_hash, valid_from, valid_to, is_current, source_system, source_order_id
)
WITH c AS (
  SELECT
    o.customer_unique_id,
    cu.customer_zip_code_prefix,
    cu.customer_city,
    cu.customer_state,
    cu.region_name,
    cu.market_code,
    MD5(CONCAT_WS('|', COALESCE(cu.customer_zip_code_prefix, ''), COALESCE(cu.customer_city, ''), COALESCE(cu.customer_state, ''))) AS address_hash,
    o.order_purchase_ts,
    o.order_id,
    o.source_system
  FROM ECOM_DB.SILVER.ORDERS o
  JOIN ECOM_DB.SILVER.CUSTOMERS cu ON cu.customer_id = o.customer_id
  WHERE NOT o.is_post_anchor_history
    AND NOT EXISTS (SELECT 1 FROM ECOM_DB.SILVER.CUSTOMERS_HISTORY h WHERE h.customer_unique_id = o.customer_unique_id)
),
one_per_ts AS (
  SELECT * FROM c
  QUALIFY ROW_NUMBER() OVER (PARTITION BY customer_unique_id, order_purchase_ts ORDER BY order_id DESC) = 1
),
changes AS (
  SELECT one_per_ts.*,
         LAG(address_hash) OVER (PARTITION BY customer_unique_id ORDER BY order_purchase_ts) AS prev_hash
  FROM one_per_ts
  QUALIFY prev_hash IS NULL OR prev_hash <> address_hash
),
versions AS (
  SELECT changes.*,
         LEAD(order_purchase_ts) OVER (PARTITION BY customer_unique_id ORDER BY order_purchase_ts) AS next_valid_from
  FROM changes
)
SELECT
  customer_unique_id, customer_zip_code_prefix, customer_city, customer_state, region_name, market_code,
  address_hash, order_purchase_ts, next_valid_from, next_valid_from IS NULL, source_system, order_id
FROM versions;