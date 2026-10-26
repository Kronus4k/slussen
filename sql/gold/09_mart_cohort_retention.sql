-- Gold MART_COHORT_RETENTION: monthly cohort retention per market as a dense grid.
-- Grain: one row per cohort month, market and month since the first GMV order, from 0 up to
--   the latest month with GMV orders, including months where nobody returned (0 active).
-- Cohort = month of a person's first GMV order, in the market of that order.
-- Month-N retention = SUM(active_customers) / SUM(cohort_size) at months_since_first = N.
--   This is only correct because every cohort has a row for every month; never average rates.
-- The latest month is still in progress, so the newest cohorts' rates are understated until
--   the month ends.
-- Runs as: DATA_ENGINEER (owns Gold) on TRANSFORM_WH.
-- Rerun: re-creates the table, and CREATE OR REPLACE drops the row access policy, the tags and
--   the comments. After any rerun, run sql/governance/03, sql/governance/04 and
--   sql/gold/10_comments.sql again before anyone reads Gold.
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
-- Each person's first GMV order sets the cohort month and the cohort market;
-- order_id breaks ties at the same timestamp.
cohort AS (
  SELECT customer_unique_id, order_month AS cohort_month, market_code
  FROM gmv_orders
  QUALIFY ROW_NUMBER() OVER (PARTITION BY customer_unique_id ORDER BY order_purchase_ts, order_id) = 1
),
-- A person counts as active in a month with any GMV order, in any market.
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
),
-- Calendar months from DIM_DATE, up to the latest month with GMV orders.
-- DIM_DATE is a view over GENERATOR; reading it from a dynamic table is the proven path.
months AS (
  SELECT DISTINCT d.month_start
  FROM ECOM_DB.GOLD.DIM_DATE d
  WHERE d.month_start <= (SELECT MAX(order_month) FROM gmv_orders)
),
-- The dense grid: every cohort with every month from its cohort month on. Without it, months
-- where nobody returned would have no row and drop out of SUM(cohort_size), which inflated
-- retention (month 0 rows dominated small markets).
grid AS (
  SELECT s.cohort_month, s.market_code, s.cohort_size,
         DATEDIFF('month', s.cohort_month, m.month_start) AS months_since_first
  FROM sizes s
  JOIN months m ON m.month_start >= s.cohort_month
)
SELECT
  g.cohort_month,
  g.market_code,
  g.months_since_first,
  g.cohort_size,
  COALESCE(a.active_customers, 0) AS active_customers,
  ROUND(COALESCE(a.active_customers, 0) / g.cohort_size, 4) AS retention_rate
FROM grid g
LEFT JOIN active a
  ON a.cohort_month = g.cohort_month
 AND a.market_code = g.market_code
 AND a.months_since_first = g.months_since_first;