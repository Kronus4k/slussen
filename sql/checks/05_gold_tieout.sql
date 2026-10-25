USE ROLE DATA_ENGINEER;
USE WAREHOUSE TRANSFORM_WH;

WITH m AS (
  SELECT 'fct_orders_rows' AS metric,
         (SELECT COUNT(*) FROM ECOM_DB.SILVER.ORDERS WHERE in_kpi_timeline)::NUMBER(38,2) AS expected_value,
         (SELECT COUNT(*) FROM ECOM_DB.GOLD.FCT_ORDERS)::NUMBER(38,2) AS actual_value
  UNION ALL
  SELECT 'fct_orders_unique',
         (SELECT COUNT(*) FROM ECOM_DB.GOLD.FCT_ORDERS),
         (SELECT COUNT(DISTINCT order_id) FROM ECOM_DB.GOLD.FCT_ORDERS)
  UNION ALL
  SELECT 'gmv_gold_vs_silver',
         (SELECT SUM(i.price + i.freight_value) FROM ECOM_DB.SILVER.ORDERS o JOIN ECOM_DB.SILVER.ORDER_ITEMS i ON i.order_id = o.order_id
          WHERE o.in_kpi_timeline AND o.order_status NOT IN ('canceled', 'unavailable')),
         (SELECT SUM(gmv) FROM ECOM_DB.GOLD.FCT_ORDERS)
  UNION ALL
  SELECT 'fct_items_rows',
         (SELECT COUNT(*) FROM ECOM_DB.SILVER.ORDER_ITEMS i JOIN ECOM_DB.SILVER.ORDERS o ON o.order_id = i.order_id WHERE o.in_kpi_timeline),
         (SELECT COUNT(*) FROM ECOM_DB.GOLD.FCT_ORDER_ITEMS)
  UNION ALL
  SELECT 'items_gmv_vs_orders_gmv',
         (SELECT SUM(gmv) FROM ECOM_DB.GOLD.FCT_ORDERS),
         (SELECT SUM(gmv) FROM ECOM_DB.GOLD.FCT_ORDER_ITEMS)
  UNION ALL
  SELECT 'items_orphan_products',
         0,
         (SELECT COUNT(*) FROM ECOM_DB.GOLD.FCT_ORDER_ITEMS f LEFT JOIN ECOM_DB.GOLD.DIM_PRODUCT d ON d.product_id = f.product_id WHERE d.product_id IS NULL)
  UNION ALL
  SELECT 'dim_product_rows',
         (SELECT COUNT(*) + 1 FROM ECOM_DB.SILVER.PRODUCTS),
         (SELECT COUNT(*) FROM ECOM_DB.GOLD.DIM_PRODUCT)
  UNION ALL
  SELECT 'dim_customer_rows',
         (SELECT COUNT(DISTINCT customer_unique_id) FROM ECOM_DB.GOLD.FCT_ORDERS),
         (SELECT COUNT(*) FROM ECOM_DB.GOLD.DIM_CUSTOMER)
  UNION ALL
  SELECT 'dim_customer_lifetime_gmv',
         (SELECT SUM(gmv) FROM ECOM_DB.GOLD.FCT_ORDERS),
         (SELECT SUM(lifetime_gmv) FROM ECOM_DB.GOLD.DIM_CUSTOMER)
  UNION ALL
  SELECT 'daily_gmv',
         (SELECT SUM(gmv) FROM ECOM_DB.GOLD.FCT_ORDERS),
         (SELECT SUM(gmv) FROM ECOM_DB.GOLD.MART_DAILY_REVENUE)
  UNION ALL
  SELECT 'daily_grid_complete',
         (SELECT (DATEDIFF('day', MIN(date_day), MAX(date_day)) + 1) * (SELECT COUNT(*) FROM ECOM_DB.GOLD.DIM_MARKET) FROM ECOM_DB.GOLD.MART_DAILY_REVENUE),
         (SELECT COUNT(*) FROM ECOM_DB.GOLD.MART_DAILY_REVENUE)
  UNION ALL
  SELECT 'category_gmv',
         (SELECT SUM(gmv) FROM ECOM_DB.GOLD.FCT_ORDERS),
         (SELECT SUM(gmv) FROM ECOM_DB.GOLD.MART_CATEGORY_MONTHLY)
  UNION ALL
  SELECT 'category_share_groups_off',
         0,
         (SELECT COUNT(*) FROM (SELECT month_start, market_code, ABS(SUM(gmv_share_in_market) - 1) AS d
                               FROM ECOM_DB.GOLD.MART_CATEGORY_MONTHLY GROUP BY 1, 2) WHERE d > 0.0001)
  UNION ALL
  SELECT 'cohort_people',
         (SELECT COUNT(DISTINCT customer_unique_id) FROM ECOM_DB.GOLD.FCT_ORDERS WHERE is_gmv_order),
         (SELECT SUM(active_customers) FROM ECOM_DB.GOLD.MART_COHORT_RETENTION WHERE months_since_first = 0)
  UNION ALL
  SELECT 'cohort_month0_not_100pct',
         0,
         (SELECT COUNT(*) FROM ECOM_DB.GOLD.MART_COHORT_RETENTION WHERE months_since_first = 0 AND retention_rate <> 1)
  UNION ALL
  SELECT 'null_market_rows',
         0,
         (SELECT COUNT(*) FROM ECOM_DB.GOLD.FCT_ORDERS WHERE market_code IS NULL)
         + (SELECT COUNT(*) FROM ECOM_DB.GOLD.FCT_ORDER_ITEMS WHERE market_code IS NULL)
         + (SELECT COUNT(*) FROM ECOM_DB.GOLD.DIM_CUSTOMER WHERE market_code IS NULL)
  UNION ALL
  SELECT 'history_people_vs_order_people',
         (SELECT COUNT(DISTINCT customer_unique_id) FROM ECOM_DB.SILVER.ORDERS WHERE NOT is_post_anchor_history),
         (SELECT COUNT(DISTINCT customer_unique_id) FROM ECOM_DB.SILVER.CUSTOMERS_HISTORY WHERE is_current)
)
SELECT OBJECT_CONSTRUCT(
  'metrics', COUNT(*),
  'all_match', BOOLAND_AGG(expected_value = actual_value),
  'mismatches', ARRAY_AGG(IFF(expected_value = actual_value, NULL,
                OBJECT_CONSTRUCT('metric', metric, 'expected', TO_VARCHAR(expected_value), 'actual', TO_VARCHAR(actual_value))))
) AS result
FROM m;