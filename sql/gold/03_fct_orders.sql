USE ROLE DATA_ENGINEER;

CREATE OR REPLACE DYNAMIC TABLE ECOM_DB.GOLD.FCT_ORDERS
  TARGET_LAG = '12 hours'
  WAREHOUSE = TRANSFORM_WH
  REFRESH_MODE = AUTO
AS
WITH items AS (
  SELECT order_id, COUNT(*) AS item_count, SUM(price) AS items_value, SUM(freight_value) AS freight_value
  FROM ECOM_DB.SILVER.ORDER_ITEMS
  GROUP BY order_id
),
base AS (
  SELECT
    o.order_id,
    o.order_date_local,
    r.market_code,
    o.customer_unique_id,
    o.customer_id,
    o.source_system,
    o.order_status,
    o.order_purchase_ts,
    o.order_approved_ts,
    o.order_delivered_customer_ts,
    o.order_estimated_delivery_date,
    COALESCE(i.item_count, 0) AS item_count,
    COALESCE(i.items_value, 0)::NUMBER(12,2) AS items_value,
    COALESCE(i.freight_value, 0)::NUMBER(12,2) AS freight_value,
    (COALESCE(i.items_value, 0) + COALESCE(i.freight_value, 0))::NUMBER(12,2) AS order_value,
    o.order_status NOT IN ('canceled', 'unavailable') AS is_gmv_order,
    p.payment_total,
    p.primary_payment_type,
    p.max_installments
  FROM ECOM_DB.SILVER.ORDERS o
  LEFT JOIN ECOM_DB.SILVER.REF_STATE_REGION r ON r.state_code = o.customer_state
  LEFT JOIN items i ON i.order_id = o.order_id
  LEFT JOIN ECOM_DB.SILVER.PAYMENTS p ON p.order_id = o.order_id
  WHERE o.in_kpi_timeline
),
numbered AS (
  SELECT base.*,
         ROW_NUMBER() OVER (PARTITION BY customer_unique_id ORDER BY order_purchase_ts, order_id) AS customer_order_number
  FROM base
)
SELECT
  order_id,
  order_date_local,
  market_code,
  customer_unique_id,
  customer_id,
  source_system,
  order_status,
  order_purchase_ts,
  order_approved_ts,
  order_delivered_customer_ts,
  order_estimated_delivery_date,
  item_count,
  items_value,
  freight_value,
  order_value,
  is_gmv_order,
  IFF(is_gmv_order, order_value, 0)::NUMBER(12,2) AS gmv,
  IFF(order_status = 'delivered', order_value, 0)::NUMBER(12,2) AS delivered_gmv,
  payment_total,
  primary_payment_type,
  max_installments,
  customer_order_number,
  customer_order_number = 1 AS is_first_order
FROM numbered;