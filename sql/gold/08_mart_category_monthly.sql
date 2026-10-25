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
    COUNT(DISTINCT f.order_id) AS orders,
    COUNT(*) AS items,
    SUM(f.gmv) AS gmv
  FROM ECOM_DB.GOLD.FCT_ORDER_ITEMS f
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
    DENSE_RANK() OVER (PARTITION BY month_start, market_code ORDER BY gmv DESC) AS gmv_rank_in_market,
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
  IFF(p.gmv > 0, ROUND((r.gmv - p.gmv) / p.gmv, 4), NULL) AS gmv_mom_change
FROM ranked r
LEFT JOIN ranked p
  ON p.market_code = r.market_code
 AND p.category = r.category
 AND p.month_start = DATEADD('month', -1, r.month_start);