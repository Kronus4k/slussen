USE ROLE PLATFORM_ADMIN;
ALTER SESSION SET USE_CACHED_RESULT = FALSE;

USE WAREHOUSE BENCH_GEN1_WH;

ALTER SESSION SET QUERY_TAG = 'bench:gen1:q1:cold';
SELECT COUNT(*) AS day_markets, SUM(gmv) AS gmv, MAX(gmv_7d) AS max_gmv_7d FROM (
  SELECT d, market_code, gmv,
         AVG(gmv) OVER (PARTITION BY market_code ORDER BY d ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS gmv_7d
  FROM (
    SELECT o.order_date_local AS d, r.market_code, SUM(i.price + i.freight_value) AS gmv
    FROM ECOM_DB.SILVER.ORDERS o
    JOIN ECOM_DB.SILVER.ORDER_ITEMS i ON i.order_id = o.order_id
    JOIN ECOM_DB.SILVER.REF_STATE_REGION r ON r.state_code = o.customer_state
    LEFT JOIN ECOM_DB.SILVER.PAYMENTS p ON p.order_id = o.order_id
    WHERE o.in_kpi_timeline AND o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY 1, 2
  )
);
ALTER SESSION SET QUERY_TAG = 'bench:gen1:q1:warm1';
SELECT COUNT(*) AS day_markets, SUM(gmv) AS gmv, MAX(gmv_7d) AS max_gmv_7d FROM (
  SELECT d, market_code, gmv,
         AVG(gmv) OVER (PARTITION BY market_code ORDER BY d ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS gmv_7d
  FROM (
    SELECT o.order_date_local AS d, r.market_code, SUM(i.price + i.freight_value) AS gmv
    FROM ECOM_DB.SILVER.ORDERS o
    JOIN ECOM_DB.SILVER.ORDER_ITEMS i ON i.order_id = o.order_id
    JOIN ECOM_DB.SILVER.REF_STATE_REGION r ON r.state_code = o.customer_state
    LEFT JOIN ECOM_DB.SILVER.PAYMENTS p ON p.order_id = o.order_id
    WHERE o.in_kpi_timeline AND o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY 1, 2
  )
);
ALTER SESSION SET QUERY_TAG = 'bench:gen1:q1:warm2';
SELECT COUNT(*) AS day_markets, SUM(gmv) AS gmv, MAX(gmv_7d) AS max_gmv_7d FROM (
  SELECT d, market_code, gmv,
         AVG(gmv) OVER (PARTITION BY market_code ORDER BY d ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS gmv_7d
  FROM (
    SELECT o.order_date_local AS d, r.market_code, SUM(i.price + i.freight_value) AS gmv
    FROM ECOM_DB.SILVER.ORDERS o
    JOIN ECOM_DB.SILVER.ORDER_ITEMS i ON i.order_id = o.order_id
    JOIN ECOM_DB.SILVER.REF_STATE_REGION r ON r.state_code = o.customer_state
    LEFT JOIN ECOM_DB.SILVER.PAYMENTS p ON p.order_id = o.order_id
    WHERE o.in_kpi_timeline AND o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY 1, 2
  )
);
ALTER SESSION SET QUERY_TAG = 'bench:gen1:q2:cold';
SELECT COUNT(*) AS states, SUM(zips) AS zips, MAX(median_lat) AS max_median_lat FROM (
  SELECT geolocation_state, COUNT(DISTINCT geolocation_zip_code_prefix) AS zips, MEDIAN(geolocation_lat) AS median_lat
  FROM ECOM_DB.BRONZE.OLIST_GEOLOCATION
  GROUP BY geolocation_state
);
ALTER SESSION SET QUERY_TAG = 'bench:gen1:q2:warm1';
SELECT COUNT(*) AS states, SUM(zips) AS zips, MAX(median_lat) AS max_median_lat FROM (
  SELECT geolocation_state, COUNT(DISTINCT geolocation_zip_code_prefix) AS zips, MEDIAN(geolocation_lat) AS median_lat
  FROM ECOM_DB.BRONZE.OLIST_GEOLOCATION
  GROUP BY geolocation_state
);
ALTER SESSION SET QUERY_TAG = 'bench:gen1:q2:warm2';
SELECT COUNT(*) AS states, SUM(zips) AS zips, MAX(median_lat) AS max_median_lat FROM (
  SELECT geolocation_state, COUNT(DISTINCT geolocation_zip_code_prefix) AS zips, MEDIAN(geolocation_lat) AS median_lat
  FROM ECOM_DB.BRONZE.OLIST_GEOLOCATION
  GROUP BY geolocation_state
);

USE WAREHOUSE BENCH_GEN2_WH;

ALTER SESSION SET QUERY_TAG = 'bench:gen2:q1:cold';
SELECT COUNT(*) AS day_markets, SUM(gmv) AS gmv, MAX(gmv_7d) AS max_gmv_7d FROM (
  SELECT d, market_code, gmv,
         AVG(gmv) OVER (PARTITION BY market_code ORDER BY d ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS gmv_7d
  FROM (
    SELECT o.order_date_local AS d, r.market_code, SUM(i.price + i.freight_value) AS gmv
    FROM ECOM_DB.SILVER.ORDERS o
    JOIN ECOM_DB.SILVER.ORDER_ITEMS i ON i.order_id = o.order_id
    JOIN ECOM_DB.SILVER.REF_STATE_REGION r ON r.state_code = o.customer_state
    LEFT JOIN ECOM_DB.SILVER.PAYMENTS p ON p.order_id = o.order_id
    WHERE o.in_kpi_timeline AND o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY 1, 2
  )
);
ALTER SESSION SET QUERY_TAG = 'bench:gen2:q1:warm1';
SELECT COUNT(*) AS day_markets, SUM(gmv) AS gmv, MAX(gmv_7d) AS max_gmv_7d FROM (
  SELECT d, market_code, gmv,
         AVG(gmv) OVER (PARTITION BY market_code ORDER BY d ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS gmv_7d
  FROM (
    SELECT o.order_date_local AS d, r.market_code, SUM(i.price + i.freight_value) AS gmv
    FROM ECOM_DB.SILVER.ORDERS o
    JOIN ECOM_DB.SILVER.ORDER_ITEMS i ON i.order_id = o.order_id
    JOIN ECOM_DB.SILVER.REF_STATE_REGION r ON r.state_code = o.customer_state
    LEFT JOIN ECOM_DB.SILVER.PAYMENTS p ON p.order_id = o.order_id
    WHERE o.in_kpi_timeline AND o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY 1, 2
  )
);
ALTER SESSION SET QUERY_TAG = 'bench:gen2:q1:warm2';
SELECT COUNT(*) AS day_markets, SUM(gmv) AS gmv, MAX(gmv_7d) AS max_gmv_7d FROM (
  SELECT d, market_code, gmv,
         AVG(gmv) OVER (PARTITION BY market_code ORDER BY d ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS gmv_7d
  FROM (
    SELECT o.order_date_local AS d, r.market_code, SUM(i.price + i.freight_value) AS gmv
    FROM ECOM_DB.SILVER.ORDERS o
    JOIN ECOM_DB.SILVER.ORDER_ITEMS i ON i.order_id = o.order_id
    JOIN ECOM_DB.SILVER.REF_STATE_REGION r ON r.state_code = o.customer_state
    LEFT JOIN ECOM_DB.SILVER.PAYMENTS p ON p.order_id = o.order_id
    WHERE o.in_kpi_timeline AND o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY 1, 2
  )
);
ALTER SESSION SET QUERY_TAG = 'bench:gen2:q2:cold';
SELECT COUNT(*) AS states, SUM(zips) AS zips, MAX(median_lat) AS max_median_lat FROM (
  SELECT geolocation_state, COUNT(DISTINCT geolocation_zip_code_prefix) AS zips, MEDIAN(geolocation_lat) AS median_lat
  FROM ECOM_DB.BRONZE.OLIST_GEOLOCATION
  GROUP BY geolocation_state
);
ALTER SESSION SET QUERY_TAG = 'bench:gen2:q2:warm1';
SELECT COUNT(*) AS states, SUM(zips) AS zips, MAX(median_lat) AS max_median_lat FROM (
  SELECT geolocation_state, COUNT(DISTINCT geolocation_zip_code_prefix) AS zips, MEDIAN(geolocation_lat) AS median_lat
  FROM ECOM_DB.BRONZE.OLIST_GEOLOCATION
  GROUP BY geolocation_state
);
ALTER SESSION SET QUERY_TAG = 'bench:gen2:q2:warm2';
SELECT COUNT(*) AS states, SUM(zips) AS zips, MAX(median_lat) AS max_median_lat FROM (
  SELECT geolocation_state, COUNT(DISTINCT geolocation_zip_code_prefix) AS zips, MEDIAN(geolocation_lat) AS median_lat
  FROM ECOM_DB.BRONZE.OLIST_GEOLOCATION
  GROUP BY geolocation_state
);

ALTER SESSION UNSET QUERY_TAG;
ALTER SESSION SET USE_CACHED_RESULT = TRUE;
USE ROLE DATA_ENGINEER;