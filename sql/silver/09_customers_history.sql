-- Silver CUSTOMERS_HISTORY: address history per customer (SCD type 2), plus the stream that feeds it.
-- Grain: one row per customer_unique_id per address version; is_current marks the open version.
-- This file creates the table and the stream and does the one-time initial load from Silver.
-- After that, the serverless task in the next file adds new versions from live ops events.
-- Runs as: DATA_ENGINEER (owns Silver) on TRANSFORM_WH.
-- Rerun: safe. Table and stream use IF NOT EXISTS (both hold state), and the initial load
--   only inserts into an empty table.
USE ROLE DATA_ENGINEER;
USE WAREHOUSE TRANSFORM_WH;

-- A stateful table, not a dynamic table: CREATE OR REPLACE would wipe the history.
CREATE TABLE IF NOT EXISTS ECOM_DB.SILVER.CUSTOMERS_HISTORY (
  customer_unique_id VARCHAR NOT NULL,
  customer_zip_code_prefix VARCHAR,
  customer_city VARCHAR,
  customer_state VARCHAR,
  region_name VARCHAR,
  market_code VARCHAR,
  address_hash VARCHAR NOT NULL,
  valid_from TIMESTAMP_TZ NOT NULL,
  valid_to TIMESTAMP_TZ,
  is_current BOOLEAN NOT NULL,
  source_system VARCHAR NOT NULL,
  source_order_id VARCHAR NOT NULL,
  _merged_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);

-- New ops events since the task last ran. APPEND_ONLY fits because Bronze is append-only.
-- IF NOT EXISTS matters: CREATE OR REPLACE would reset the stream's offset and lose or replay events.
-- Creating the stream also turns on change tracking on the Bronze table.
-- It is created before the initial load, so no event can fall between the two; an event seen
-- by both adds nothing, because the task only adds a version when the address differs.
CREATE STREAM IF NOT EXISTS ECOM_DB.SILVER.STR_OPS_ORDERS_FOR_CUSTOMERS
  ON TABLE ECOM_DB.BRONZE.OPS_ORDERS
  APPEND_ONLY = TRUE;

-- Initial load: rebuild every customer's address versions from their orders so far.
INSERT INTO ECOM_DB.SILVER.CUSTOMERS_HISTORY (
  customer_unique_id, customer_zip_code_prefix, customer_city, customer_state, region_name, market_code,
  address_hash, valid_from, valid_to, is_current, source_system, source_order_id
)
WITH c AS (
  SELECT
    o.customer_unique_id,
    cu.customer_zip_code_prefix,
    cu.customer_city,
    cu.customer_state,
    cu.region_name,
    cu.market_code,
    -- One value per address. COALESCE keeps missing parts comparable,
    -- and the '|' separator keeps ('ab', 'c') apart from ('a', 'bc').
    MD5(CONCAT_WS('|', COALESCE(cu.customer_zip_code_prefix, ''), COALESCE(cu.customer_city, ''), COALESCE(cu.customer_state, ''))) AS address_hash,
    o.order_purchase_ts,
    o.order_id,
    o.source_system
  FROM ECOM_DB.SILVER.ORDERS o
  JOIN ECOM_DB.SILVER.CUSTOMERS cu ON cu.customer_id = o.customer_id
  -- Shifted Olist orders that land in the live period are left out,
  -- so history never creates versions inside it.
  WHERE NOT o.is_post_anchor_history
),
-- Two orders by the same person at the same moment: keep one, so LAG and LEAD below
-- see a strict order and the result is deterministic.
one_per_ts AS (
  SELECT * FROM c
  QUALIFY ROW_NUMBER() OVER (PARTITION BY customer_unique_id, order_purchase_ts ORDER BY order_id DESC) = 1
),
-- Keep a person's first order and every order whose address differs from the previous order.
-- LAG runs over all orders before QUALIFY filters, so A, A, B, A gives three versions: A, B, A.
changes AS (
  SELECT one_per_ts.*,
         LAG(address_hash) OVER (PARTITION BY customer_unique_id ORDER BY order_purchase_ts) AS prev_hash
  FROM one_per_ts
  QUALIFY prev_hash IS NULL OR prev_hash <> address_hash
),
-- A version is valid until the next one starts; the last version stays open (NULL).
versions AS (
  SELECT changes.*,
         LEAD(order_purchase_ts) OVER (PARTITION BY customer_unique_id ORDER BY order_purchase_ts) AS next_valid_from
  FROM changes
)
-- Mapped by position to the column list above: purchase time becomes valid_from,
-- the next version's start becomes valid_to, and an open version is current.
SELECT
  customer_unique_id, customer_zip_code_prefix, customer_city, customer_state, region_name, market_code,
  address_hash, order_purchase_ts, next_valid_from, next_valid_from IS NULL, source_system, order_id
FROM versions
-- Runs once: after the initial load, only the task writes to this table.
WHERE NOT EXISTS (SELECT 1 FROM ECOM_DB.SILVER.CUSTOMERS_HISTORY);