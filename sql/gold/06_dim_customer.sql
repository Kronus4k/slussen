USE ROLE DATA_ENGINEER;

CREATE OR REPLACE DYNAMIC TABLE ECOM_DB.GOLD.DIM_CUSTOMER
  TARGET_LAG = '12 hours'
  WAREHOUSE = TRANSFORM_WH
  REFRESH_MODE = AUTO
AS
WITH person_orders AS (
  SELECT
    customer_unique_id,
    MIN(order_date_local) AS first_order_date,
    MAX(order_date_local) AS last_order_date,
    COUNT(*) AS order_count,
    COUNT_IF(is_gmv_order) AS gmv_order_count,
    SUM(gmv) AS lifetime_gmv
  FROM ECOM_DB.GOLD.FCT_ORDERS
  GROUP BY customer_unique_id
),
cur AS (
  SELECT customer_unique_id, customer_zip_code_prefix, customer_city, customer_state, region_name, market_code
  FROM ECOM_DB.SILVER.CUSTOMERS_HISTORY
  WHERE is_current
)
SELECT
  p.customer_unique_id,
  c.customer_zip_code_prefix,
  c.customer_city,
  c.customer_state,
  c.region_name,
  c.market_code,
  p.first_order_date,
  DATE_TRUNC('month', p.first_order_date) AS cohort_month,
  p.last_order_date,
  p.order_count,
  p.gmv_order_count,
  p.lifetime_gmv::NUMBER(14,2) AS lifetime_gmv,
  p.gmv_order_count >= 2 AS is_repeat_customer,
  IFF(p.lifetime_gmv > 0, NTILE(4) OVER (PARTITION BY p.lifetime_gmv > 0 ORDER BY p.lifetime_gmv), NULL) AS spend_quartile
FROM person_orders p
LEFT JOIN cur c ON c.customer_unique_id = p.customer_unique_id;