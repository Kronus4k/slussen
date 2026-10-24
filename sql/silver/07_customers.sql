USE ROLE DATA_ENGINEER;
USE WAREHOUSE TRANSFORM_WH;

CREATE OR REPLACE DYNAMIC TABLE ECOM_DB.SILVER.CUSTOMERS
  TARGET_LAG = 'DOWNSTREAM'
  WAREHOUSE = TRANSFORM_WH
  REFRESH_MODE = AUTO
AS
WITH olist AS (
  SELECT
    c.customer_id,
    c.customer_unique_id,
    c.customer_zip_code_prefix,
    c.customer_city,
    c.customer_state,
    'olist' AS source_system,
    c._file_name AS source_file,
    c._loaded_at
  FROM ECOM_DB.BRONZE.OLIST_CUSTOMERS c
),
ops AS (
  SELECT
    b.customer_id,
    b.customer_unique_id,
    b.customer_zip_code_prefix,
    b.customer_city,
    b.customer_state,
    'ops' AS source_system,
    b._file_name AS source_file,
    b._loaded_at
  FROM ECOM_DB.BRONZE.OPS_ORDERS b
  QUALIFY ROW_NUMBER() OVER (PARTITION BY b.customer_id ORDER BY b.event_ts DESC, b.event_id DESC) = 1
),
unioned AS (
  SELECT * FROM olist
  UNION ALL
  SELECT * FROM ops
)
SELECT
  u.customer_id,
  u.customer_unique_id,
  u.customer_zip_code_prefix,
  u.customer_city,
  u.customer_state,
  r.region_name,
  r.market_code,
  u.source_system,
  u.source_file,
  u._loaded_at
FROM unioned u
LEFT JOIN ECOM_DB.SILVER.REF_STATE_REGION r ON r.state_code = u.customer_state;