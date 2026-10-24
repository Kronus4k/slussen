USE ROLE DATA_ENGINEER;
USE WAREHOUSE TRANSFORM_WH;

CREATE OR REPLACE DYNAMIC TABLE ECOM_DB.SILVER.ORDERS
  TARGET_LAG = 'DOWNSTREAM'
  WAREHOUSE = TRANSFORM_WH
  REFRESH_MODE = AUTO
AS
WITH shift AS (
  SELECT shift_days, source_anchor_date, target_anchor_date, source_time_zone
  FROM ECOM_DB.SILVER.REF_DATE_SHIFT
  WHERE shift_key = 'olist_history'
),
olist_local AS (
  SELECT
    o.order_id,
    o.customer_id,
    c.customer_unique_id,
    c.customer_state,
    o.order_status,
    DATEADD('day', s.shift_days, o.order_purchase_timestamp) AS purchase_local,
    DATEADD('day', s.shift_days, o.order_approved_at) AS approved_local,
    DATEADD('day', s.shift_days, o.order_delivered_carrier_date) AS carrier_local,
    DATEADD('day', s.shift_days, o.order_delivered_customer_date) AS delivered_local,
    DATEADD('day', s.shift_days, o.order_estimated_delivery_date)::DATE AS order_estimated_delivery_date,
    o.order_purchase_timestamp >= s.source_anchor_date AS is_post_anchor_history,
    s.source_time_zone,
    o._file_name,
    o._loaded_at
  FROM ECOM_DB.BRONZE.OLIST_ORDERS o
  CROSS JOIN shift s
  LEFT JOIN ECOM_DB.BRONZE.OLIST_CUSTOMERS c ON c.customer_id = o.customer_id
),
olist AS (
  SELECT
    order_id,
    'olist' AS source_system,
    customer_id,
    customer_unique_id,
    customer_state,
    order_status,
    TO_TIMESTAMP_TZ(TO_VARCHAR(CONVERT_TIMEZONE(source_time_zone, 'UTC', purchase_local), 'YYYY-MM-DD HH24:MI:SS.FF6') || ' +00:00', 'YYYY-MM-DD HH24:MI:SS.FF6 TZH:TZM') AS order_purchase_ts,
    TO_TIMESTAMP_TZ(TO_VARCHAR(CONVERT_TIMEZONE(source_time_zone, 'UTC', approved_local), 'YYYY-MM-DD HH24:MI:SS.FF6') || ' +00:00', 'YYYY-MM-DD HH24:MI:SS.FF6 TZH:TZM') AS order_approved_ts,
    TO_TIMESTAMP_TZ(TO_VARCHAR(CONVERT_TIMEZONE(source_time_zone, 'UTC', carrier_local), 'YYYY-MM-DD HH24:MI:SS.FF6') || ' +00:00', 'YYYY-MM-DD HH24:MI:SS.FF6 TZH:TZM') AS order_delivered_carrier_ts,
    TO_TIMESTAMP_TZ(TO_VARCHAR(CONVERT_TIMEZONE(source_time_zone, 'UTC', delivered_local), 'YYYY-MM-DD HH24:MI:SS.FF6') || ' +00:00', 'YYYY-MM-DD HH24:MI:SS.FF6 TZH:TZM') AS order_delivered_customer_ts,
    order_estimated_delivery_date,
    purchase_local::DATE AS order_date_local,
    is_post_anchor_history,
    FALSE AS is_pre_anchor_live,
    NOT is_post_anchor_history AS in_kpi_timeline,
    NULL::VARCHAR AS source_event_id,
    _file_name AS source_file,
    _loaded_at
  FROM olist_local
),
ops AS (
  SELECT
    b.order_id,
    'ops' AS source_system,
    b.customer_id,
    b.customer_unique_id,
    b.customer_state,
    b.order_status,
    b.order_purchase_ts,
    b.order_approved_ts,
    b.order_delivered_carrier_ts,
    b.order_delivered_customer_ts,
    b.order_estimated_delivery_date,
    CONVERT_TIMEZONE(s.source_time_zone, b.order_purchase_ts)::DATE AS order_date_local,
    FALSE AS is_post_anchor_history,
    CONVERT_TIMEZONE(s.source_time_zone, b.order_purchase_ts)::DATE < s.target_anchor_date AS is_pre_anchor_live,
    CONVERT_TIMEZONE(s.source_time_zone, b.order_purchase_ts)::DATE >= s.target_anchor_date AS in_kpi_timeline,
    b.event_id AS source_event_id,
    b._file_name AS source_file,
    b._loaded_at
  FROM ECOM_DB.BRONZE.OPS_ORDERS b
  CROSS JOIN shift s
  QUALIFY ROW_NUMBER() OVER (PARTITION BY b.order_id ORDER BY b.event_ts DESC, b.event_id DESC) = 1
)
SELECT * FROM olist
UNION ALL
SELECT * FROM ops;