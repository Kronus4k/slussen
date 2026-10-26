-- Silver TSK_MERGE_CUSTOMERS_HISTORY: keeps the customer address history (SCD type 2) current.
-- Reads new ops events from the stream and, per customer, closes the current address version
-- and opens a new one when the address changed; new customers get their first version.
-- Grain of the target: one row per customer_unique_id per address version.
-- Runs as: DATA_ENGINEER, which needs EXECUTE MANAGED TASK at CREATE for a serverless task.
-- Rerun: safe. The task holds no data (state lives in the table and the stream);
--   CREATE OR REPLACE leaves it suspended, so the file ends with RESUME.
USE ROLE DATA_ENGINEER;

-- Serverless (no WAREHOUSE) and triggered (no SCHEDULE): it runs when the stream has data.
-- A triggered serverless task needs TARGET_COMPLETION_INTERVAL; Snowflake checks it at RESUME.
-- When the stream is empty the run is SKIPPED and costs no compute.
CREATE OR REPLACE TASK ECOM_DB.SILVER.TSK_MERGE_CUSTOMERS_HISTORY
  TARGET_COMPLETION_INTERVAL = '15 MINUTES'
  WHEN SYSTEM$STREAM_HAS_DATA('ECOM_DB.SILVER.STR_OPS_ORDERS_FOR_CUSTOMERS')
AS
-- Committing this MERGE consumes the stream (moves its offset), even when nothing changes.
MERGE INTO ECOM_DB.SILVER.CUSTOMERS_HISTORY h
USING (
  -- The latest address per customer among the new events.
  WITH s AS (
    SELECT
      b.customer_unique_id,
      b.customer_zip_code_prefix,
      b.customer_city,
      b.customer_state,
      r.region_name,
      r.market_code,
      -- Same hash as the initial load, so versions from both paths compare correctly.
      MD5(CONCAT_WS('|', COALESCE(b.customer_zip_code_prefix, ''), COALESCE(b.customer_city, ''), COALESCE(b.customer_state, ''))) AS address_hash,
      b.order_purchase_ts AS valid_from,
      b.order_id
    FROM ECOM_DB.SILVER.STR_OPS_ORDERS_FOR_CUSTOMERS b
    LEFT JOIN ECOM_DB.SILVER.REF_STATE_REGION r ON r.state_code = b.customer_state
    -- An append-only stream only returns inserts; the filter states that intent.
    WHERE b.METADATA$ACTION = 'INSERT'
    -- One row per customer per run: the newest purchase. Status updates re-send an order with
    -- the same purchase time, so order_id and event_ts break the remaining ties.
    QUALIFY ROW_NUMBER() OVER (PARTITION BY b.customer_unique_id ORDER BY b.order_purchase_ts DESC, b.order_id DESC, b.event_ts DESC) = 1
  ),
  cur AS (
    SELECT customer_unique_id, address_hash, valid_from
    FROM ECOM_DB.SILVER.CUSTOMERS_HISTORY
    WHERE is_current
  ),
  -- Only real changes go on: a customer without history, or a different address that starts
  -- after the current version. Late events older than the current version are ignored,
  -- so history is never rewritten in the middle.
  changed AS (
    SELECT s.*, cur.customer_unique_id IS NOT NULL AS has_current
    FROM s
    LEFT JOIN cur ON cur.customer_unique_id = s.customer_unique_id
    WHERE cur.customer_unique_id IS NULL
       OR (cur.address_hash <> s.address_hash AND s.valid_from > cur.valid_from)
  )
  -- The union trick: one MERGE can't both update and insert for the same key, so a changed
  -- customer appears twice. With merge_key set, the row matches the current version and closes it.
  -- With merge_key NULL, it can never match, so it inserts the new version.
  -- A new customer has no current version: only the first copy exists, and it inserts.
  SELECT customer_unique_id AS merge_key, changed.* FROM changed
  UNION ALL
  SELECT NULL AS merge_key, changed.* FROM changed WHERE has_current
) x
-- Only the open version can be closed.
ON h.customer_unique_id = x.merge_key AND h.is_current
WHEN MATCHED THEN UPDATE SET
  valid_to = x.valid_from,
  is_current = FALSE,
  _merged_at = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT (
  customer_unique_id, customer_zip_code_prefix, customer_city, customer_state, region_name, market_code,
  address_hash, valid_from, valid_to, is_current, source_system, source_order_id
) VALUES (
  x.customer_unique_id, x.customer_zip_code_prefix, x.customer_city, x.customer_state, x.region_name, x.market_code,
  x.address_hash, x.valid_from, NULL, TRUE, 'ops', x.order_id
);

-- New and replaced tasks start suspended.
ALTER TASK ECOM_DB.SILVER.TSK_MERGE_CUSTOMERS_HISTORY RESUME;