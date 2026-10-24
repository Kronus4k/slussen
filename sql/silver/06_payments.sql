USE ROLE DATA_ENGINEER;
USE WAREHOUSE TRANSFORM_WH;

CREATE OR REPLACE DYNAMIC TABLE ECOM_DB.SILVER.PAYMENTS
  TARGET_LAG = 'DOWNSTREAM'
  WAREHOUSE = TRANSFORM_WH
  REFRESH_MODE = AUTO
AS
WITH lines AS (
  SELECT
    p.order_id,
    'olist' AS source_system,
    p.payment_sequential,
    p.payment_type,
    p.payment_installments,
    p.payment_value::NUMBER(10,2) AS payment_value
  FROM ECOM_DB.BRONZE.OLIST_ORDER_PAYMENTS p
  UNION ALL
  SELECT
    b.order_id,
    'ops' AS source_system,
    f.value:payment_sequential::NUMBER(38,0),
    f.value:payment_type::VARCHAR,
    f.value:payment_installments::NUMBER(38,0),
    f.value:payment_value::NUMBER(10,2)
  FROM ECOM_DB.SILVER.ORDERS o
  JOIN ECOM_DB.BRONZE.OPS_ORDERS b ON b.event_id = o.source_event_id
  , LATERAL FLATTEN(INPUT => b.payments) f
  WHERE o.source_system = 'ops'
)
SELECT
  order_id,
  source_system,
  SUM(payment_value)::NUMBER(12,2) AS payment_total,
  COUNT(*) AS payment_rows,
  MAX(payment_installments) AS max_installments,
  GET(ARRAY_AGG(payment_type) WITHIN GROUP (ORDER BY payment_value DESC, payment_sequential), 0)::VARCHAR AS primary_payment_type,
  ARRAY_SORT(ARRAY_DISTINCT(ARRAY_AGG(payment_type))) AS payment_types
FROM lines
GROUP BY order_id, source_system;