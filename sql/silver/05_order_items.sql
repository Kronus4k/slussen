USE ROLE DATA_ENGINEER;
USE WAREHOUSE TRANSFORM_WH;

CREATE OR REPLACE DYNAMIC TABLE ECOM_DB.SILVER.ORDER_ITEMS
  TARGET_LAG = 'DOWNSTREAM'
  WAREHOUSE = TRANSFORM_WH
  REFRESH_MODE = AUTO
AS
WITH shift AS (
  SELECT shift_days, source_time_zone
  FROM ECOM_DB.SILVER.REF_DATE_SHIFT
  WHERE shift_key = 'olist_history'
),
olist AS (
  SELECT
    i.order_id,
    i.order_item_id,
    'olist' AS source_system,
    i.product_id,
    i.seller_id,
    TO_TIMESTAMP_TZ(TO_VARCHAR(CONVERT_TIMEZONE(s.source_time_zone, 'UTC', DATEADD('day', s.shift_days, i.shipping_limit_date)), 'YYYY-MM-DD HH24:MI:SS.FF6') || ' +00:00', 'YYYY-MM-DD HH24:MI:SS.FF6 TZH:TZM') AS shipping_limit_ts,
    i.price::NUMBER(10,2) AS price,
    i.freight_value::NUMBER(10,2) AS freight_value,
    NULL::VARCHAR AS source_event_id,
    i._file_name AS source_file,
    i._loaded_at
  FROM ECOM_DB.BRONZE.OLIST_ORDER_ITEMS i
  CROSS JOIN shift s
),
ops AS (
  SELECT
    b.order_id,
    f.value:order_item_id::NUMBER(38,0) AS order_item_id,
    'ops' AS source_system,
    f.value:product_id::VARCHAR AS product_id,
    f.value:seller_id::VARCHAR AS seller_id,
    NULL::TIMESTAMP_TZ AS shipping_limit_ts,
    f.value:price::NUMBER(10,2) AS price,
    f.value:freight_value::NUMBER(10,2) AS freight_value,
    b.event_id AS source_event_id,
    b._file_name AS source_file,
    b._loaded_at
  FROM ECOM_DB.SILVER.ORDERS o
  JOIN ECOM_DB.BRONZE.OPS_ORDERS b ON b.event_id = o.source_event_id
  , LATERAL FLATTEN(INPUT => b.items) f
  WHERE o.source_system = 'ops'
)
SELECT * FROM olist
UNION ALL
SELECT * FROM ops;