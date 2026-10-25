USE ROLE DATA_ENGINEER;
USE WAREHOUSE TRANSFORM_WH;

CREATE TABLE IF NOT EXISTS ECOM_DB.SILVER.CUSTOMERS_HISTORY (
  customer_unique_id VARCHAR NOT NULL,
  customer_zip_code_prefix VARCHAR,
  customer_city VARCHAR,
  customer_state VARCHAR,
  region_name VARCHAR,
  market_code VARCHAR,
  address_hash VARCHAR NOT NULL,
  valid_from TIMESTAMP_TZ NOT NULL,
  valid_to TIMESTAMP_TZ,
  is_current BOOLEAN NOT NULL,
  source_system VARCHAR NOT NULL,
  source_order_id VARCHAR NOT NULL,
  _merged_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE STREAM IF NOT EXISTS ECOM_DB.SILVER.STR_OPS_ORDERS_FOR_CUSTOMERS
  ON TABLE ECOM_DB.BRONZE.OPS_ORDERS
  APPEND_ONLY = TRUE;

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
FROM versions
WHERE NOT EXISTS (SELECT 1 FROM ECOM_DB.SILVER.CUSTOMERS_HISTORY);