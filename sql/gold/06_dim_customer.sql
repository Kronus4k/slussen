-- Gold DIM_CUSTOMER: one row per person, with current address and market, order counts,
-- lifetime GMV, cohort month, repeat flag and spend quartile.
-- Grain: one row per customer_unique_id with at least one order on the KPI timeline.
-- Order facts come from FCT_ORDERS; the current address from the open version in
-- SILVER.CUSTOMERS_HISTORY.
-- Runs as: DATA_ENGINEER (owns Gold) on TRANSFORM_WH.
-- Rerun: re-creates the table, and CREATE OR REPLACE drops the row access policy, the PII and
--   DOMAIN tags and the comments. After any rerun, run sql/governance/03, sql/governance/04
--   and sql/gold/10_comments.sql again before anyone reads Gold.
USE ROLE DATA_ENGINEER;

CREATE OR REPLACE DYNAMIC TABLE ECOM_DB.GOLD.DIM_CUSTOMER
  TARGET_LAG = '12 hours'
  WAREHOUSE = TRANSFORM_WH
  REFRESH_MODE = AUTO
AS
-- Order facts per person over every order on the KPI timeline, whatever the status.
WITH person_orders AS (
  SELECT
    customer_unique_id,
    MIN(order_date_local) AS first_order_date,
    -- The cohort starts with the first order that counts for GMV; empty when there is none.
    -- The earliest purchase also has the earliest reporting day, so this gives the same month
    -- as the cohort in MART_COHORT_RETENTION.
    MIN(IFF(is_gmv_order, order_date_local, NULL)) AS first_gmv_order_date,
    MAX(order_date_local) AS last_order_date,
    COUNT(*) AS order_count,
    COUNT_IF(is_gmv_order) AS gmv_order_count,
    SUM(gmv) AS lifetime_gmv
  FROM ECOM_DB.GOLD.FCT_ORDERS
  GROUP BY customer_unique_id
),
-- The open address version is the current address and market.
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
  -- Current market. Facts carry the market at order time instead.
  -- A person without address history gets an empty market, which only roles mapped to ALL see.
  c.market_code,
  p.first_order_date,
  DATE_TRUNC('month', p.first_gmv_order_date) AS cohort_month,
  p.last_order_date,
  p.order_count,
  p.gmv_order_count,
  p.lifetime_gmv::NUMBER(14,2) AS lifetime_gmv,
  p.gmv_order_count >= 2 AS is_repeat_customer,
  -- Quartiles only among people with GMV (partition on lifetime_gmv > 0); 1 = lowest spend.
  -- People without GMV get no quartile.
  IFF(p.lifetime_gmv > 0, NTILE(4) OVER (PARTITION BY p.lifetime_gmv > 0 ORDER BY p.lifetime_gmv), NULL) AS spend_quartile
FROM person_orders p
LEFT JOIN cur c ON c.customer_unique_id = p.customer_unique_id;