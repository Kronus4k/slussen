USE ROLE DATA_ENGINEER;

CREATE OR REPLACE DYNAMIC TABLE ECOM_DB.GOLD.MART_DAILY_REVENUE
  TARGET_LAG = '12 hours'
  WAREHOUSE = TRANSFORM_WH
  REFRESH_MODE = AUTO
AS
WITH bounds AS (
  SELECT MIN(order_date_local) AS first_day, MAX(order_date_local) AS last_day
  FROM ECOM_DB.GOLD.FCT_ORDERS
),
grid AS (
  SELECT d.date_day, d.is_analysis_window, d.is_live_period, m.market_code
  FROM ECOM_DB.GOLD.DIM_DATE d
  CROSS JOIN ECOM_DB.GOLD.DIM_MARKET m
  CROSS JOIN bounds b
  WHERE d.date_day BETWEEN b.first_day AND b.last_day
),
daily AS (
  SELECT order_date_local, market_code, COUNT(*) AS orders, COUNT_IF(is_gmv_order) AS gmv_orders, SUM(gmv) AS gmv
  FROM ECOM_DB.GOLD.FCT_ORDERS
  GROUP BY order_date_local, market_code
),
joined AS (
  SELECT g.date_day, g.market_code, g.is_analysis_window, g.is_live_period,
         COALESCE(d.orders, 0) AS orders,
         COALESCE(d.gmv_orders, 0) AS gmv_orders,
         COALESCE(d.gmv, 0)::NUMBER(14,2) AS gmv
  FROM grid g
  LEFT JOIN daily d ON d.order_date_local = g.date_day AND d.market_code = g.market_code
)
SELECT
  date_day,
  market_code,
  is_analysis_window,
  is_live_period,
  orders,
  gmv_orders,
  gmv,
  SUM(gmv) OVER (PARTITION BY market_code ORDER BY date_day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)::NUMBER(14,2) AS gmv_7d_sum,
  AVG(gmv) OVER (PARTITION BY market_code ORDER BY date_day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)::NUMBER(14,2) AS gmv_7d_avg,
  AVG(gmv) OVER (PARTITION BY market_code ORDER BY date_day ROWS BETWEEN 27 PRECEDING AND CURRENT ROW)::NUMBER(14,2) AS gmv_28d_avg,
  SUM(gmv) OVER (PARTITION BY market_code, YEAR(date_day) ORDER BY date_day ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)::NUMBER(14,2) AS gmv_ytd,
  LAG(gmv, 7) OVER (PARTITION BY market_code ORDER BY date_day)::NUMBER(14,2) AS gmv_same_day_last_week
FROM joined;