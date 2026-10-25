USE ROLE DATA_ENGINEER;

CREATE OR REPLACE DYNAMIC TABLE ECOM_DB.GOLD.MART_COHORT_RETENTION
  TARGET_LAG = '12 hours'
  WAREHOUSE = TRANSFORM_WH
  REFRESH_MODE = AUTO
AS
WITH gmv_orders AS (
  SELECT customer_unique_id, order_id, order_purchase_ts, market_code,
         DATE_TRUNC('month', order_date_local) AS order_month
  FROM ECOM_DB.GOLD.FCT_ORDERS
  WHERE is_gmv_order
),
cohort AS (
  SELECT customer_unique_id, order_month AS cohort_month, market_code
  FROM gmv_orders
  QUALIFY ROW_NUMBER() OVER (PARTITION BY customer_unique_id ORDER BY order_purchase_ts, order_id) = 1
),
activity AS (
  SELECT DISTINCT customer_unique_id, order_month AS activity_month
  FROM gmv_orders
),
sizes AS (
  SELECT cohort_month, market_code, COUNT(*) AS cohort_size
  FROM cohort
  GROUP BY cohort_month, market_code
),
active AS (
  SELECT c.cohort_month, c.market_code,
         DATEDIFF('month', c.cohort_month, a.activity_month) AS months_since_first,
         COUNT(*) AS active_customers
  FROM cohort c
  JOIN activity a ON a.customer_unique_id = c.customer_unique_id
  GROUP BY 1, 2, 3
)
SELECT
  a.cohort_month,
  a.market_code,
  a.months_since_first,
  s.cohort_size,
  a.active_customers,
  ROUND(a.active_customers / s.cohort_size, 4) AS retention_rate
FROM active a
JOIN sizes s ON s.cohort_month = a.cohort_month AND s.market_code = a.market_code;