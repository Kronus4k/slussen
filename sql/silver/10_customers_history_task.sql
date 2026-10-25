USE ROLE DATA_ENGINEER;

CREATE OR REPLACE TASK ECOM_DB.SILVER.TSK_MERGE_CUSTOMERS_HISTORY
  TARGET_COMPLETION_INTERVAL = '15 MINUTES'
  WHEN SYSTEM$STREAM_HAS_DATA('ECOM_DB.SILVER.STR_OPS_ORDERS_FOR_CUSTOMERS')
AS
MERGE INTO ECOM_DB.SILVER.CUSTOMERS_HISTORY h
USING (
  WITH s AS (
    SELECT
      b.customer_unique_id,
      b.customer_zip_code_prefix,
      b.customer_city,
      b.customer_state,
      r.region_name,
      r.market_code,
      MD5(CONCAT_WS('|', COALESCE(b.customer_zip_code_prefix, ''), COALESCE(b.customer_city, ''), COALESCE(b.customer_state, ''))) AS address_hash,
      b.order_purchase_ts AS valid_from,
      b.order_id
    FROM ECOM_DB.SILVER.STR_OPS_ORDERS_FOR_CUSTOMERS b
    LEFT JOIN ECOM_DB.SILVER.REF_STATE_REGION r ON r.state_code = b.customer_state
    WHERE b.METADATA$ACTION = 'INSERT'
    QUALIFY ROW_NUMBER() OVER (PARTITION BY b.customer_unique_id ORDER BY b.order_purchase_ts DESC, b.order_id DESC, b.event_ts DESC) = 1
  ),
  cur AS (
    SELECT customer_unique_id, address_hash, valid_from
    FROM ECOM_DB.SILVER.CUSTOMERS_HISTORY
    WHERE is_current
  ),
  changed AS (
    SELECT s.*, cur.customer_unique_id IS NOT NULL AS has_current
    FROM s
    LEFT JOIN cur ON cur.customer_unique_id = s.customer_unique_id
    WHERE cur.customer_unique_id IS NULL
       OR (cur.address_hash <> s.address_hash AND s.valid_from > cur.valid_from)
  )
  SELECT customer_unique_id AS merge_key, changed.* FROM changed
  UNION ALL
  SELECT NULL AS merge_key, changed.* FROM changed WHERE has_current
) x
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

ALTER TASK ECOM_DB.SILVER.TSK_MERGE_CUSTOMERS_HISTORY RESUME;