-- Semantic view SV_COMMERCIAL over the Gold commercial star, for Cortex Analyst and SQL.
--
-- Grain: one semantic view; each metric is defined exactly like its Power BI measure, so a
--        natural-language answer and the matching dashboard tile return the same number.
-- Runs as: DATA_ENGINEER (holds CREATE SEMANTIC VIEW on GOLD through GOLD_RW).
-- Safe to rerun: yes. CREATE OR REPLACE ... COPY GRANTS keeps the grants the analyst roles
--                hold on the view (without COPY GRANTS they would be dropped). Read access
--                comes from the future grants in sql/setup/18.
--
-- Row access: queries through the semantic view run as the caller, and RAP_MARKET on the
-- Gold tables filters rows by market exactly as for direct queries.
-- Dates are Sao Paulo reporting days (DIM_DATE.date_day), not UTC days.
-- customers is joined to markets only (current market), never to orders: the same rule as
-- the Power BI model, so a customer's current region can't relabel past orders.
-- Semantic names differ from column names (total_gmv, not gmv) so no name is ambiguous.
-- Verified queries are written against the logical tables (orders, dates, ...) and sit
-- inside single quotes, so they contain no quotes: dates use DATE_FROM_PARTS.
-- Where a dimension renames a Gold column, use the dimension name: d.in_analysis_window
-- and p.product_category compile, the Gold names d.is_analysis_window and p.category don't.
-- The rolling 28-day query anchors on the day before the latest day with GMV, because the
-- latest day is still filling with 4-hourly live batches (same rule as the dashboard).

USE ROLE DATA_ENGINEER;
USE WAREHOUSE TRANSFORM_WH;

CREATE OR REPLACE SEMANTIC VIEW ECOM_DB.GOLD.SV_COMMERCIAL

  TABLES (
    orders AS ECOM_DB.GOLD.FCT_ORDERS
      PRIMARY KEY (order_id)
      WITH SYNONYMS ('sales orders')
      COMMENT = 'One row per order on the KPI timeline; market is the market at order time',
    items AS ECOM_DB.GOLD.FCT_ORDER_ITEMS
      PRIMARY KEY (order_id, order_item_id)
      WITH SYNONYMS ('order lines', 'line items')
      COMMENT = 'One row per order item; used for product category analysis',
    dates AS ECOM_DB.GOLD.DIM_DATE
      PRIMARY KEY (date_day)
      WITH SYNONYMS ('calendar')
      COMMENT = 'Calendar of Sao Paulo reporting days',
    markets AS ECOM_DB.GOLD.DIM_MARKET
      PRIMARY KEY (market_code)
      WITH SYNONYMS ('regions')
      COMMENT = 'The five Brazilian regions used as markets',
    products AS ECOM_DB.GOLD.DIM_PRODUCT
      PRIMARY KEY (product_id)
      COMMENT = 'Products with their English category name',
    customers AS ECOM_DB.GOLD.DIM_CUSTOMER
      PRIMARY KEY (customer_unique_id)
      WITH SYNONYMS ('buyers', 'people')
      COMMENT = 'One row per person; market is the current market',
    cohorts AS ECOM_DB.GOLD.MART_COHORT_RETENTION
      PRIMARY KEY (cohort_month, market_code, months_since_first)
      COMMENT = 'Dense cohort grid: every cohort month, market and month offset, zeros included'
  )

  RELATIONSHIPS (
    orders_to_dates AS orders (order_date_local) REFERENCES dates,
    orders_to_markets AS orders (market_code) REFERENCES markets,
    items_to_dates AS items (order_date_local) REFERENCES dates,
    items_to_markets AS items (market_code) REFERENCES markets,
    items_to_products AS items (product_id) REFERENCES products,
    customers_to_markets AS customers (market_code) REFERENCES markets,
    cohorts_to_markets AS cohorts (market_code) REFERENCES markets
  )

  DIMENSIONS (
    dates.order_day AS date_day
      WITH SYNONYMS ('date', 'day')
      COMMENT = 'Sao Paulo reporting day of the purchase',
    dates.order_month AS month_start
      WITH SYNONYMS ('month')
      COMMENT = 'First day of the month',
    dates.order_year AS year
      COMMENT = 'Calendar year',
    dates.order_week AS iso_week_start
      WITH SYNONYMS ('week')
      COMMENT = 'Monday of the ISO week',
    dates.in_analysis_window AS is_analysis_window
      COMMENT = 'TRUE from 2025-02-23 on; earlier days are sparse history and skew trends',
    dates.in_live_period AS is_live_period
      COMMENT = 'TRUE for days fed by the live operations feed',
    markets.region_code AS market_code
      WITH SYNONYMS ('market code')
      COMMENT = 'Market code, for example SUDESTE',
    markets.region_name AS market_name
      WITH SYNONYMS ('market', 'region')
      COMMENT = 'Market name, for example Sudeste',
    products.product_category AS category
      WITH SYNONYMS ('category')
      COMMENT = 'English product category; unknown when the source had none',
    orders.status AS order_status
      COMMENT = 'Latest order status',
    orders.payment_type AS primary_payment_type
      COMMENT = 'Payment type with the largest share of the order payment',
    customers.spend_quartile_rank AS spend_quartile
      WITH SYNONYMS ('spend quartile')
      COMMENT = 'Quartile of lifetime GMV among buyers; 4 is the highest spend',
    customers.first_gmv_cohort AS cohort_month
      COMMENT = 'Month of the first GMV order of the person',
    cohorts.cohort AS cohort_month
      WITH SYNONYMS ('cohort month')
      COMMENT = 'Month of the first GMV order of the cohort',
    cohorts.months_after_first AS months_since_first
      COMMENT = 'Months since the cohort month; 1 is the first month after'
  )

  METRICS (
    orders.total_gmv AS SUM(orders.gmv)
      WITH SYNONYMS ('GMV', 'revenue', 'sales')
      COMMENT = 'Gross merchandise value: item price plus freight, canceled and unavailable orders excluded',
    orders.gmv_order_count AS SUM(IFF(orders.is_gmv_order, 1, 0))
      WITH SYNONYMS ('GMV orders', 'order count')
      COMMENT = 'Orders that count toward GMV',
    orders.order_count_all_statuses AS COUNT(orders.order_id)
      COMMENT = 'All orders including canceled and unavailable',
    orders.average_order_value AS SUM(orders.gmv) / NULLIF(SUM(IFF(orders.is_gmv_order, 1, 0)), 0)
      WITH SYNONYMS ('AOV')
      COMMENT = 'GMV divided by GMV orders',
    orders.median_order_value AS MEDIAN(IFF(orders.is_gmv_order, orders.gmv, NULL))
      COMMENT = 'Median GMV of GMV orders',
    items.item_gmv_total AS SUM(items.gmv)
      WITH SYNONYMS ('item GMV', 'category GMV')
      COMMENT = 'GMV summed per item; use for product category questions',
    customers.buyer_count AS SUM(IFF(customers.gmv_order_count >= 1, 1, 0))
      WITH SYNONYMS ('buyers')
      COMMENT = 'People with at least one GMV order',
    customers.repeat_customer_count AS SUM(IFF(customers.is_repeat_customer, 1, 0))
      COMMENT = 'People with two or more GMV orders',
    customers.repeat_customer_rate AS SUM(IFF(customers.is_repeat_customer, 1, 0))
        / NULLIF(SUM(IFF(customers.gmv_order_count >= 1, 1, 0)), 0)
      WITH SYNONYMS ('repeat rate')
      COMMENT = 'Repeat customers divided by buyers',
    cohorts.month_1_retention AS SUM(IFF(cohorts.months_since_first = 1, cohorts.active_customers, 0))
        / NULLIF(SUM(IFF(cohorts.months_since_first = 1, cohorts.cohort_size, 0)), 0)
      WITH SYNONYMS ('retention', 'month one retention')
      COMMENT = 'Share of a cohort that ordered again in the first month after its cohort month'
  )

  COMMENT = 'Commercial performance: GMV, orders, categories, repeat customers and retention'

  AI_SQL_GENERATION 'Dates are Sao Paulo reporting days. Always filter in_analysis_window = TRUE, for totals and for trends, unless the user explicitly asks for all time; this matches the dashboard. GMV already excludes canceled and unavailable orders. Use total_gmv for revenue questions and item_gmv_total only for product category questions. Without a market in the question, answer for all markets the user can see. Round money to 2 decimals and rates to 2 decimals as percentages.'

  AI_VERIFIED_QUERIES (
    gmv_analysis_window AS (
      QUESTION 'What is the total GMV and number of GMV orders in the analysis window?'
      VERIFIED_AT 1793491200
      ONBOARDING_QUESTION TRUE
      SQL 'SELECT SUM(o.gmv) AS total_gmv,
                  SUM(IFF(o.is_gmv_order, 1, 0)) AS gmv_orders
           FROM orders AS o
           JOIN dates AS d ON o.order_date_local = d.date_day
           WHERE d.in_analysis_window'
    ),
    gmv_last_28_days AS (
      QUESTION 'How did GMV in the last 28 days compare with the 28 days before?'
      VERIFIED_AT 1793491200
      ONBOARDING_QUESTION FALSE
      SQL 'WITH daily AS (
               SELECT o.order_date_local AS order_day, SUM(o.gmv) AS gmv
               FROM orders AS o
               GROUP BY o.order_date_local
           ),
           anchor AS (
               SELECT DATEADD(day, -1, MAX(order_day)) AS last_full_day
               FROM daily
               WHERE gmv > 0
           )
           SELECT a.last_full_day,
                  SUM(IFF(daily.order_day BETWEEN DATEADD(day, -27, a.last_full_day) AND a.last_full_day, daily.gmv, 0)) AS gmv_last_28_days,
                  SUM(IFF(daily.order_day BETWEEN DATEADD(day, -55, a.last_full_day) AND DATEADD(day, -28, a.last_full_day), daily.gmv, 0)) AS gmv_prior_28_days,
                  (gmv_last_28_days - gmv_prior_28_days) / NULLIF(gmv_prior_28_days, 0) AS change_pct
           FROM daily
           CROSS JOIN anchor AS a
           GROUP BY a.last_full_day'
    ),
    top_categories_sep_2026 AS (
      QUESTION 'What were the top 5 product categories by GMV in September 2026 and their share?'
      VERIFIED_AT 1793491200
      ONBOARDING_QUESTION TRUE
      SQL 'SELECT p.product_category,
                  SUM(i.gmv) AS item_gmv,
                  RATIO_TO_REPORT(SUM(i.gmv)) OVER () AS share_of_item_gmv
           FROM items AS i
           JOIN products AS p ON i.product_id = p.product_id
           WHERE i.order_date_local BETWEEN DATE_FROM_PARTS(2026, 9, 1) AND DATE_FROM_PARTS(2026, 9, 30)
           GROUP BY p.product_category
           QUALIFY ROW_NUMBER() OVER (ORDER BY SUM(i.gmv) DESC) <= 5
           ORDER BY item_gmv DESC'
    ),
    repeat_customer_rate AS (
      QUESTION 'What is the repeat customer rate?'
      VERIFIED_AT 1793491200
      ONBOARDING_QUESTION TRUE
      SQL 'SELECT SUM(IFF(c.is_repeat_customer, 1, 0))
                  / NULLIF(SUM(IFF(c.gmv_order_count >= 1, 1, 0)), 0) AS repeat_customer_rate
           FROM customers AS c'
    ),
    month_1_retention AS (
      QUESTION 'What is the month-1 retention of our customer cohorts?'
      VERIFIED_AT 1793491200
      ONBOARDING_QUESTION FALSE
      SQL 'SELECT SUM(IFF(h.months_since_first = 1, h.active_customers, 0))
                  / NULLIF(SUM(IFF(h.months_since_first = 1, h.cohort_size, 0)), 0) AS month_1_retention
           FROM cohorts AS h'
    )
  )

  COPY GRANTS;

DESCRIBE SEMANTIC VIEW ECOM_DB.GOLD.SV_COMMERCIAL;

SELECT "object_kind", "object_name", "property"
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
WHERE "object_kind" ILIKE '%VERIFIED%' OR "property" ILIKE '%VERIFIED%'
ORDER BY "object_name", "property";