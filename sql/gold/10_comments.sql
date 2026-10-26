-- Business-language comments on every Gold object and column, read by people in Snowsight,
-- by Power BI and by the natural-language layer.
-- Grain: one ALTER per object and per column; nothing here changes data or structure.
-- Dynamic tables get table and column comments. The views DIM_DATE and DIM_MARKET get a
-- view-level comment only: Snowflake documents no column comment command for existing views.
-- Runs as: DATA_ENGINEER (owns Gold). Run with Run All; the file is DDL only.
-- Rerun: safe; it writes the same text again. Rerun it after any Gold object is re-created,
--   together with sql/governance/03 and 04, because CREATE OR REPLACE drops the comments too.
-- Amounts are in BRL.
USE ROLE DATA_ENGINEER;

-- Object comments
ALTER DYNAMIC TABLE ECOM_DB.GOLD.FCT_ORDERS SET COMMENT = 'Orders on the KPI timeline, one row per order: shifted Olist history before 2026-10-24, the live ops feed from then on. GMV = item prices plus freight, excluding canceled and unavailable orders.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.FCT_ORDER_ITEMS SET COMMENT = 'Items of the orders in FCT_ORDERS, one row per order item. Item GMV adds up to the order GMV.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.DIM_CUSTOMER SET COMMENT = 'Customers, one row per person (customer_unique_id), with current address and market, order counts, lifetime GMV, repeat flag and spend quartile. Zip prefix and city are masked unless PII_READER is active.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.DIM_PRODUCT SET COMMENT = 'Products, one row per product plus one unknown member for items whose product is not in the catalog.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.MART_DAILY_REVENUE SET COMMENT = 'Daily orders and GMV per market, one row per day and market including days without orders, with 7- and 28-day moving averages, year-to-date GMV and the same day last week.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.MART_CATEGORY_MONTHLY SET COMMENT = 'Monthly GMV per category and market, with rank and share within the market and the change versus the previous month.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.MART_COHORT_RETENTION SET COMMENT = 'Monthly cohort retention per market. Cohort = month of the first GMV order, in the market of that order. Company-wide retention = SUM(active_customers) / SUM(cohort_size), never an average of rates.';
ALTER VIEW ECOM_DB.GOLD.DIM_DATE SET COMMENT = 'Calendar, one row per day. is_analysis_window skips the sparse first months of history; is_live_period marks days covered by the live ops feed.';
ALTER VIEW ECOM_DB.GOLD.DIM_MARKET SET COMMENT = 'Markets: Brazil''s five regions. One row per market; row access is granted per market.';

-- FCT_ORDERS columns
ALTER DYNAMIC TABLE ECOM_DB.GOLD.FCT_ORDERS ALTER COLUMN order_id COMMENT 'Order identifier.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.FCT_ORDERS ALTER COLUMN order_date_local COMMENT 'Reporting day: purchase date in Sao Paulo time. Joins to DIM_DATE.date_day.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.FCT_ORDERS ALTER COLUMN market_code COMMENT 'Market at order time, from the customer state on the order. Row access filters on this column.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.FCT_ORDERS ALTER COLUMN customer_unique_id COMMENT 'Person identifier, stable across orders. Joins to DIM_CUSTOMER.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.FCT_ORDERS ALTER COLUMN customer_id COMMENT 'Source customer key, new for every order. Use customer_unique_id to count people.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.FCT_ORDERS ALTER COLUMN source_system COMMENT 'olist for shifted history, ops for the live feed.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.FCT_ORDERS ALTER COLUMN order_status COMMENT 'Latest order status, for example delivered, shipped or canceled.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.FCT_ORDERS ALTER COLUMN order_purchase_ts COMMENT 'Purchase time in UTC.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.FCT_ORDERS ALTER COLUMN order_approved_ts COMMENT 'Payment approval time in UTC.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.FCT_ORDERS ALTER COLUMN order_delivered_customer_ts COMMENT 'Delivery time to the customer in UTC; empty until delivered.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.FCT_ORDERS ALTER COLUMN order_estimated_delivery_date COMMENT 'Delivery date promised to the customer.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.FCT_ORDERS ALTER COLUMN item_count COMMENT 'Number of items; 0 for orders without items.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.FCT_ORDERS ALTER COLUMN items_value COMMENT 'Sum of item prices.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.FCT_ORDERS ALTER COLUMN freight_value COMMENT 'Sum of freight charges.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.FCT_ORDERS ALTER COLUMN order_value COMMENT 'Item prices plus freight, whatever the status.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.FCT_ORDERS ALTER COLUMN is_gmv_order COMMENT 'TRUE unless the order is canceled or unavailable.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.FCT_ORDERS ALTER COLUMN gmv COMMENT 'Gross merchandise value of the order: item prices plus freight; 0 for canceled or unavailable orders.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.FCT_ORDERS ALTER COLUMN delivered_gmv COMMENT 'Order value of delivered orders; 0 otherwise.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.FCT_ORDERS ALTER COLUMN payment_total COMMENT 'Sum of payments; can differ from order_value (vouchers, installment interest).';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.FCT_ORDERS ALTER COLUMN primary_payment_type COMMENT 'Main payment type of the order.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.FCT_ORDERS ALTER COLUMN max_installments COMMENT 'Highest number of installments among the payments of the order.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.FCT_ORDERS ALTER COLUMN customer_order_number COMMENT 'Position of the order in the person''s order sequence (1 = first), counting all statuses.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.FCT_ORDERS ALTER COLUMN is_first_order COMMENT 'TRUE for the person''s first order of any status. Cohorts use the first GMV order instead.';

-- FCT_ORDER_ITEMS columns
ALTER DYNAMIC TABLE ECOM_DB.GOLD.FCT_ORDER_ITEMS ALTER COLUMN order_id COMMENT 'Order identifier. Joins to FCT_ORDERS.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.FCT_ORDER_ITEMS ALTER COLUMN order_item_id COMMENT 'Position of the item within its order (1, 2, ...).';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.FCT_ORDER_ITEMS ALTER COLUMN order_date_local COMMENT 'Reporting day of the order: purchase date in Sao Paulo time.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.FCT_ORDER_ITEMS ALTER COLUMN market_code COMMENT 'Market of the order at order time. Row access filters on this column.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.FCT_ORDER_ITEMS ALTER COLUMN customer_unique_id COMMENT 'Person who placed the order.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.FCT_ORDER_ITEMS ALTER COLUMN order_status COMMENT 'Latest status of the order.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.FCT_ORDER_ITEMS ALTER COLUMN is_gmv_order COMMENT 'TRUE unless the order is canceled or unavailable.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.FCT_ORDER_ITEMS ALTER COLUMN product_id COMMENT 'Product identifier; unknown when the product is not in the catalog. Joins to DIM_PRODUCT.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.FCT_ORDER_ITEMS ALTER COLUMN seller_id COMMENT 'Seller of the item.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.FCT_ORDER_ITEMS ALTER COLUMN price COMMENT 'Item price.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.FCT_ORDER_ITEMS ALTER COLUMN freight_value COMMENT 'Freight charged for the item.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.FCT_ORDER_ITEMS ALTER COLUMN item_value COMMENT 'Price plus freight, whatever the order status.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.FCT_ORDER_ITEMS ALTER COLUMN gmv COMMENT 'Item GMV: price plus freight; 0 when the order is canceled or unavailable.';

-- DIM_CUSTOMER columns
ALTER DYNAMIC TABLE ECOM_DB.GOLD.DIM_CUSTOMER ALTER COLUMN customer_unique_id COMMENT 'Person identifier, stable across orders.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.DIM_CUSTOMER ALTER COLUMN customer_zip_code_prefix COMMENT 'First five digits of the current zip code. Personal data: masked unless PII_READER is active.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.DIM_CUSTOMER ALTER COLUMN customer_city COMMENT 'Current city. Personal data: masked unless PII_READER is active.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.DIM_CUSTOMER ALTER COLUMN customer_state COMMENT 'Current state (two-letter code).';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.DIM_CUSTOMER ALTER COLUMN region_name COMMENT 'Region of the current state.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.DIM_CUSTOMER ALTER COLUMN market_code COMMENT 'Current market of the person; facts use the market at order time instead. Row access filters on this column.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.DIM_CUSTOMER ALTER COLUMN first_order_date COMMENT 'Reporting day of the first order of any status.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.DIM_CUSTOMER ALTER COLUMN cohort_month COMMENT 'Month of the first GMV order (not canceled or unavailable); empty without one. Same cohort as in MART_COHORT_RETENTION.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.DIM_CUSTOMER ALTER COLUMN last_order_date COMMENT 'Reporting day of the latest order of any status.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.DIM_CUSTOMER ALTER COLUMN order_count COMMENT 'Orders of any status on the KPI timeline.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.DIM_CUSTOMER ALTER COLUMN gmv_order_count COMMENT 'Orders that are not canceled or unavailable.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.DIM_CUSTOMER ALTER COLUMN lifetime_gmv COMMENT 'Total GMV of the person on the KPI timeline.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.DIM_CUSTOMER ALTER COLUMN is_repeat_customer COMMENT 'TRUE for two or more GMV orders.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.DIM_CUSTOMER ALTER COLUMN spend_quartile COMMENT 'Quartile of lifetime GMV among people with GMV: 1 = lowest spend, 4 = highest; empty without GMV.';

-- DIM_PRODUCT columns
ALTER DYNAMIC TABLE ECOM_DB.GOLD.DIM_PRODUCT ALTER COLUMN product_id COMMENT 'Product identifier; unknown for the placeholder member.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.DIM_PRODUCT ALTER COLUMN category COMMENT 'Product category in English; unknown when the product has none.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.DIM_PRODUCT ALTER COLUMN category_name_pt COMMENT 'Original Portuguese category name from the source.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.DIM_PRODUCT ALTER COLUMN category_source COMMENT 'Where the English category came from in Silver; unknown_member for the placeholder row.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.DIM_PRODUCT ALTER COLUMN product_weight_g COMMENT 'Package weight in grams.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.DIM_PRODUCT ALTER COLUMN product_length_cm COMMENT 'Package length in centimetres.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.DIM_PRODUCT ALTER COLUMN product_height_cm COMMENT 'Package height in centimetres.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.DIM_PRODUCT ALTER COLUMN product_width_cm COMMENT 'Package width in centimetres.';

-- MART_DAILY_REVENUE columns
ALTER DYNAMIC TABLE ECOM_DB.GOLD.MART_DAILY_REVENUE ALTER COLUMN date_day COMMENT 'Reporting day (Sao Paulo).';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.MART_DAILY_REVENUE ALTER COLUMN market_code COMMENT 'Market at order time. Row access filters on this column.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.MART_DAILY_REVENUE ALTER COLUMN is_analysis_window COMMENT 'TRUE from the start of the analysis window; filter on it to skip the sparse first months.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.MART_DAILY_REVENUE ALTER COLUMN is_live_period COMMENT 'TRUE for days covered by the live ops feed.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.MART_DAILY_REVENUE ALTER COLUMN orders COMMENT 'Orders of any status placed that day.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.MART_DAILY_REVENUE ALTER COLUMN gmv_orders COMMENT 'Orders that count for GMV (not canceled or unavailable).';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.MART_DAILY_REVENUE ALTER COLUMN gmv COMMENT 'GMV of the day; 0 on days without orders.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.MART_DAILY_REVENUE ALTER COLUMN gmv_7d_sum COMMENT 'GMV of the last 7 calendar days including this one.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.MART_DAILY_REVENUE ALTER COLUMN gmv_7d_avg COMMENT 'Average daily GMV over the last 7 calendar days, days without orders counted as 0.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.MART_DAILY_REVENUE ALTER COLUMN gmv_28d_avg COMMENT 'Average daily GMV over the last 28 calendar days, days without orders counted as 0.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.MART_DAILY_REVENUE ALTER COLUMN gmv_ytd COMMENT 'GMV from 1 January of the same calendar year up to this day.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.MART_DAILY_REVENUE ALTER COLUMN gmv_same_day_last_week COMMENT 'GMV of the same weekday one week earlier; empty in the first week.';

-- MART_CATEGORY_MONTHLY columns
ALTER DYNAMIC TABLE ECOM_DB.GOLD.MART_CATEGORY_MONTHLY ALTER COLUMN month_start COMMENT 'First day of the month (Sao Paulo reporting days).';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.MART_CATEGORY_MONTHLY ALTER COLUMN market_code COMMENT 'Market at order time. Row access filters on this column.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.MART_CATEGORY_MONTHLY ALTER COLUMN category COMMENT 'Product category in English; unknown when the product has none.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.MART_CATEGORY_MONTHLY ALTER COLUMN orders COMMENT 'GMV orders with at least one item in the category. Does not add up across categories.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.MART_CATEGORY_MONTHLY ALTER COLUMN items COMMENT 'Items sold in the category by GMV orders.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.MART_CATEGORY_MONTHLY ALTER COLUMN gmv COMMENT 'GMV of the category in the month and market.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.MART_CATEGORY_MONTHLY ALTER COLUMN gmv_rank_in_market COMMENT 'Rank by GMV within the month and market; ties share a rank.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.MART_CATEGORY_MONTHLY ALTER COLUMN is_top5_in_market COMMENT 'TRUE when the rank is 5 or better; can include more than five categories on ties.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.MART_CATEGORY_MONTHLY ALTER COLUMN gmv_share_in_market COMMENT 'Share of the monthly GMV of the market (0 to 1). Not additive across markets.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.MART_CATEGORY_MONTHLY ALTER COLUMN gmv_prev_month COMMENT 'GMV of the same category and market in the previous calendar month; empty if none.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.MART_CATEGORY_MONTHLY ALTER COLUMN gmv_mom_change COMMENT 'Change versus the previous month as a fraction (0.25 = +25 %); empty without previous GMV.';

-- MART_COHORT_RETENTION columns
ALTER DYNAMIC TABLE ECOM_DB.GOLD.MART_COHORT_RETENTION ALTER COLUMN cohort_month COMMENT 'Month of the first GMV order of the people in the cohort.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.MART_COHORT_RETENTION ALTER COLUMN market_code COMMENT 'Market of the first GMV order. Row access filters on this column.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.MART_COHORT_RETENTION ALTER COLUMN months_since_first COMMENT 'Months after the cohort month; 0 is the cohort month itself (always 100 %).';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.MART_COHORT_RETENTION ALTER COLUMN cohort_size COMMENT 'People in the cohort.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.MART_COHORT_RETENTION ALTER COLUMN active_customers COMMENT 'People of the cohort with a GMV order in that month, in any market.';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.MART_COHORT_RETENTION ALTER COLUMN retention_rate COMMENT 'active_customers / cohort_size for this row. Combine rows with SUM(active_customers) / SUM(cohort_size), not by averaging.';