-- Gold MART_CATEGORY_MONTHLY: GMV per category per month and market, with rank, share and
-- change versus the previous month.
-- Grain: one row per month_start, market_code and category that had GMV orders that month.
-- Runs as: DATA_ENGINEER (owns Gold) on TRANSFORM_WH.
-- Rerun: re-creates the table, and CREATE OR REPLACE drops the attached row access policy
--   and tags. After any rerun, run sql/governance/03 and 04 again before anyone reads Gold.
USE ROLE DATA_ENGINEER;

CREATE OR REPLACE DYNAMIC TABLE ECOM_DB.GOLD.MART_CATEGORY_MONTHLY
  TARGET_LAG = '12 hours'
  WAREHOUSE = TRANSFORM_WH
  REFRESH_MODE = AUTO
AS
WITH monthly AS (
  SELECT
    DATE_TRUNC('month', f.order_date_local) AS month_start,
    f.market_code,
    d.category,
    -- One order can hold items from several categories, so order counts
    -- don't add up across categories; items and GMV do.
    COUNT(DISTINCT f.order_id) AS orders,
    COUNT(*) AS items,
    -- Item-level GMV adds up to the order GMV in FCT_ORDERS (checked by the Gold tie-out).
    SUM(f.gmv) AS gmv
  FROM ECOM_DB.GOLD.FCT_ORDER_ITEMS f
  -- DIM_PRODUCT is a dynamic table, not a view: a dynamic table can't read a view
  -- that sits over another dynamic table.
  JOIN ECOM_DB.GOLD.DIM_PRODUCT d ON d.product_id = f.product_id
  WHERE f.is_gmv_order
  GROUP BY 1, 2, 3
),
ranked AS (
  SELECT
    month_start,
    market_code,
    category,
    orders,
    items,
    gmv::NUMBER(14,2) AS gmv,
    -- Ties share a rank, so "top 5" can hold more than five categories.
    DENSE_RANK() OVER (PARTITION BY month_start, market_code ORDER BY gmv DESC) AS gmv_rank_in_market,
    -- Share within the month and market; the company-wide share is computed in BI.
    RATIO_TO_REPORT(gmv) OVER (PARTITION BY month_start, market_code)::NUMBER(9,6) AS gmv_share_in_market
  FROM monthly
)
SELECT
  r.month_start,
  r.market_code,
  r.category,
  r.orders,
  r.items,
  r.gmv,
  r.gmv_rank_in_market,
  r.gmv_rank_in_market <= 5 AS is_top5_in_market,
  r.gmv_share_in_market,
  p.gmv AS gmv_prev_month,
  -- NULL when there was no GMV the month before (no division by zero).
  IFF(p.gmv > 0, ROUND((r.gmv - p.gmv) / p.gmv, 4), NULL) AS gmv_mom_change
FROM ranked r
-- Self-join on exactly the previous calendar month instead of LAG.
-- LAG returns the previous row, which is an older month whenever a category had no sales
-- in between: that would have been wrong in 537 of 4,373 rows. The join gives NULL instead.
LEFT JOIN ranked p
  ON p.market_code = r.market_code
 AND p.category = r.category
 AND p.month_start = DATEADD('month', -1, r.month_start);