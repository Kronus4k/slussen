CREATE EXTERNAL TABLE IF NOT EXISTS slussen_lake.finance_settlements (
  settlement_id string COMMENT 'Unique settlement row id.',
  payout_batch_id string COMMENT 'Weekly payout batch this row belongs to.',
  order_id string COMMENT 'Order the payment belongs to.',
  payment_sequential bigint COMMENT 'Payment row number within the order.',
  payment_type string COMMENT 'Payment method.',
  gross_amount decimal(12,2) COMMENT 'Amount paid by the customer in BRL.',
  fee_amount decimal(12,2) COMMENT 'Processing fee in BRL.',
  net_amount decimal(12,2) COMMENT 'Amount paid out, gross minus fee.',
  currency string COMMENT 'ISO 4217 code, BRL.',
  payment_date date COMMENT 'Date the customer paid.',
  settlement_date date COMMENT 'Date the money was paid out; null while pending.',
  settlement_status string COMMENT 'settled, pending or disputed.',
  generated_at timestamp COMMENT 'When Finance produced the file, UTC.'
)
COMMENT 'Weekly payment settlements from the Finance team. One record per settled payment row. Contract finance_settlements v1.0.0; contract-validated Parquet from the gate.'
PARTITIONED BY (dt string)
STORED AS PARQUET
LOCATION 's3://slussen-lake-qwer/validated/finance/settlements/'
TBLPROPERTIES (
  'projection.enabled' = 'true',
  'projection.dt.type' = 'date',
  'projection.dt.format' = 'yyyy-MM-dd',
  'projection.dt.range' = '2026-01-01,NOW',
  'projection.dt.interval' = '1',
  'projection.dt.interval.unit' = 'DAYS',
  'storage.location.template' = 's3://slussen-lake-qwer/validated/finance/settlements/dt=${dt}/'
);

CREATE EXTERNAL TABLE IF NOT EXISTS slussen_lake.olist_customers (
  customer_id string COMMENT 'Per-order customer key (Olist semantics).',
  customer_unique_id string COMMENT 'Per-person customer key, used for repeat and cohort logic.',
  customer_zip_code_prefix string COMMENT 'Five-digit zip prefix, leading zeros kept.',
  customer_city string COMMENT 'Customer city.',
  customer_state string COMMENT 'Two-letter Brazilian state code, used to derive the market.'
)
COMMENT 'Historical Olist customers, one row per order-level customer id. One-off backfill. Contract olist_customers v1.0.0; contract-validated Parquet from the gate.'
PARTITIONED BY (dt string)
STORED AS PARQUET
LOCATION 's3://slussen-lake-qwer/validated/olist/customers/'
TBLPROPERTIES (
  'projection.enabled' = 'true',
  'projection.dt.type' = 'date',
  'projection.dt.format' = 'yyyy-MM-dd',
  'projection.dt.range' = '2026-01-01,NOW',
  'projection.dt.interval' = '1',
  'projection.dt.interval.unit' = 'DAYS',
  'storage.location.template' = 's3://slussen-lake-qwer/validated/olist/customers/dt=${dt}/'
);

CREATE EXTERNAL TABLE IF NOT EXISTS slussen_lake.olist_geolocation (
  geolocation_zip_code_prefix string COMMENT 'Five-digit zip prefix, leading zeros kept.',
  geolocation_lat decimal(24,20) COMMENT 'Latitude as sent, up to 20 decimals.',
  geolocation_lng decimal(24,20) COMMENT 'Longitude as sent, up to 20 decimals.',
  geolocation_city string COMMENT 'City name as sent; spelling varies.',
  geolocation_state string COMMENT 'Two-letter Brazilian state code.'
)
COMMENT 'Historical Olist zip-code coordinates. The source has no key (about 262k exact duplicate rows), so primary_key is empty and rows land as sent. One-off backfill. Contract olist_geolocation v1.0.0; contract-validated Parquet from the gate.'
PARTITIONED BY (dt string)
STORED AS PARQUET
LOCATION 's3://slussen-lake-qwer/validated/olist/geolocation/'
TBLPROPERTIES (
  'projection.enabled' = 'true',
  'projection.dt.type' = 'date',
  'projection.dt.format' = 'yyyy-MM-dd',
  'projection.dt.range' = '2026-01-01,NOW',
  'projection.dt.interval' = '1',
  'projection.dt.interval.unit' = 'DAYS',
  'storage.location.template' = 's3://slussen-lake-qwer/validated/olist/geolocation/dt=${dt}/'
);

CREATE EXTERNAL TABLE IF NOT EXISTS slussen_lake.olist_order_items (
  order_id string COMMENT 'Order identifier.',
  order_item_id bigint COMMENT 'Line number within the order, starting at 1.',
  product_id string COMMENT 'Product identifier.',
  seller_id string COMMENT 'Seller identifier.',
  shipping_limit_date timestamp COMMENT 'Latest handover time for the seller, source local time without zone.',
  price decimal(10,2) COMMENT 'Item price in BRL.',
  freight_value decimal(10,2) COMMENT 'Freight charged for the item in BRL.'
)
COMMENT 'Historical Olist order lines, one row per item in an order. One-off backfill. Contract olist_order_items v1.0.0; contract-validated Parquet from the gate.'
PARTITIONED BY (dt string)
STORED AS PARQUET
LOCATION 's3://slussen-lake-qwer/validated/olist/order_items/'
TBLPROPERTIES (
  'projection.enabled' = 'true',
  'projection.dt.type' = 'date',
  'projection.dt.format' = 'yyyy-MM-dd',
  'projection.dt.range' = '2026-01-01,NOW',
  'projection.dt.interval' = '1',
  'projection.dt.interval.unit' = 'DAYS',
  'storage.location.template' = 's3://slussen-lake-qwer/validated/olist/order_items/dt=${dt}/'
);

CREATE EXTERNAL TABLE IF NOT EXISTS slussen_lake.olist_order_payments (
  order_id string COMMENT 'Order identifier.',
  payment_sequential bigint COMMENT 'Payment row number within the order.',
  payment_type string COMMENT 'credit_card, boleto, voucher, debit_card or not_defined.',
  payment_installments bigint COMMENT 'Number of installments.',
  payment_value decimal(10,2) COMMENT 'Amount of this payment row in BRL.'
)
COMMENT 'Historical Olist payment rows; an order can have several. One-off backfill. Contract olist_order_payments v1.0.0; contract-validated Parquet from the gate.'
PARTITIONED BY (dt string)
STORED AS PARQUET
LOCATION 's3://slussen-lake-qwer/validated/olist/order_payments/'
TBLPROPERTIES (
  'projection.enabled' = 'true',
  'projection.dt.type' = 'date',
  'projection.dt.format' = 'yyyy-MM-dd',
  'projection.dt.range' = '2026-01-01,NOW',
  'projection.dt.interval' = '1',
  'projection.dt.interval.unit' = 'DAYS',
  'storage.location.template' = 's3://slussen-lake-qwer/validated/olist/order_payments/dt=${dt}/'
);

CREATE EXTERNAL TABLE IF NOT EXISTS slussen_lake.olist_order_reviews (
  review_id string COMMENT 'Review identifier; not unique on its own.',
  order_id string COMMENT 'Order the review belongs to.',
  review_score bigint COMMENT 'Score from 1 to 5.',
  review_comment_title string COMMENT 'Free-text title written by the customer, Portuguese.',
  review_comment_message string COMMENT 'Free-text comment written by the customer, Portuguese; may contain line breaks.',
  review_creation_date timestamp COMMENT 'When the review survey was sent, source local time without zone.',
  review_answer_timestamp timestamp COMMENT 'When the customer answered, source local time without zone.'
)
COMMENT 'Historical Olist customer reviews. review_id alone repeats across orders, so the key is review_id plus order_id. One-off backfill. Contract olist_order_reviews v1.0.0; contract-validated Parquet from the gate.'
PARTITIONED BY (dt string)
STORED AS PARQUET
LOCATION 's3://slussen-lake-qwer/validated/olist/order_reviews/'
TBLPROPERTIES (
  'projection.enabled' = 'true',
  'projection.dt.type' = 'date',
  'projection.dt.format' = 'yyyy-MM-dd',
  'projection.dt.range' = '2026-01-01,NOW',
  'projection.dt.interval' = '1',
  'projection.dt.interval.unit' = 'DAYS',
  'storage.location.template' = 's3://slussen-lake-qwer/validated/olist/order_reviews/dt=${dt}/'
);

CREATE EXTERNAL TABLE IF NOT EXISTS slussen_lake.olist_orders (
  order_id string COMMENT 'Order identifier.',
  customer_id string COMMENT 'Per-order customer key; join to olist_customers.',
  order_status string COMMENT 'Final order status, e.g. delivered, shipped, canceled, unavailable.',
  order_purchase_timestamp timestamp COMMENT 'Purchase time, source local time without zone.',
  order_approved_at timestamp COMMENT 'Payment approval time, source local time without zone.',
  order_delivered_carrier_date timestamp COMMENT 'Handover to carrier, source local time without zone.',
  order_delivered_customer_date timestamp COMMENT 'Delivery to customer, source local time without zone.',
  order_estimated_delivery_date timestamp COMMENT 'Promised delivery date, sent as a timestamp at midnight.'
)
COMMENT 'Historical Olist orders, one row per order. One-off backfill from the public Olist dataset. Contract olist_orders v1.0.0; contract-validated Parquet from the gate.'
PARTITIONED BY (dt string)
STORED AS PARQUET
LOCATION 's3://slussen-lake-qwer/validated/olist/orders/'
TBLPROPERTIES (
  'projection.enabled' = 'true',
  'projection.dt.type' = 'date',
  'projection.dt.format' = 'yyyy-MM-dd',
  'projection.dt.range' = '2026-01-01,NOW',
  'projection.dt.interval' = '1',
  'projection.dt.interval.unit' = 'DAYS',
  'storage.location.template' = 's3://slussen-lake-qwer/validated/olist/orders/dt=${dt}/'
);

CREATE EXTERNAL TABLE IF NOT EXISTS slussen_lake.olist_product_category_name_translation (
  product_category_name string COMMENT 'Category name in Portuguese.',
  product_category_name_english string COMMENT 'Category name in English.'
)
COMMENT 'Portuguese to English product category names from the Olist dataset. Two categories are missing. One-off backfill. Contract olist_product_category_name_translation v1.0.0; contract-validated Parquet from the gate.'
PARTITIONED BY (dt string)
STORED AS PARQUET
LOCATION 's3://slussen-lake-qwer/validated/olist/product_category_name_translation/'
TBLPROPERTIES (
  'projection.enabled' = 'true',
  'projection.dt.type' = 'date',
  'projection.dt.format' = 'yyyy-MM-dd',
  'projection.dt.range' = '2026-01-01,NOW',
  'projection.dt.interval' = '1',
  'projection.dt.interval.unit' = 'DAYS',
  'storage.location.template' = 's3://slussen-lake-qwer/validated/olist/product_category_name_translation/dt=${dt}/'
);

CREATE EXTERNAL TABLE IF NOT EXISTS slussen_lake.olist_products (
  product_id string COMMENT 'Product identifier.',
  product_category_name string COMMENT 'Category in Portuguese; null for about 610 products.',
  product_name_lenght bigint COMMENT 'Characters in the product name (source spelling).',
  product_description_lenght bigint COMMENT 'Characters in the product description (source spelling).',
  product_photos_qty bigint COMMENT 'Number of product photos.',
  product_weight_g bigint COMMENT 'Weight in grams.',
  product_length_cm bigint COMMENT 'Length in centimetres.',
  product_height_cm bigint COMMENT 'Height in centimetres.',
  product_width_cm bigint COMMENT 'Width in centimetres.'
)
COMMENT 'Historical Olist product catalogue. Column names keep the source spelling (lenght). One-off backfill. Contract olist_products v1.0.0; contract-validated Parquet from the gate.'
PARTITIONED BY (dt string)
STORED AS PARQUET
LOCATION 's3://slussen-lake-qwer/validated/olist/products/'
TBLPROPERTIES (
  'projection.enabled' = 'true',
  'projection.dt.type' = 'date',
  'projection.dt.format' = 'yyyy-MM-dd',
  'projection.dt.range' = '2026-01-01,NOW',
  'projection.dt.interval' = '1',
  'projection.dt.interval.unit' = 'DAYS',
  'storage.location.template' = 's3://slussen-lake-qwer/validated/olist/products/dt=${dt}/'
);

CREATE EXTERNAL TABLE IF NOT EXISTS slussen_lake.olist_sellers (
  seller_id string COMMENT 'Seller identifier.',
  seller_zip_code_prefix string COMMENT 'Five-digit zip prefix of the seller (a business), leading zeros kept.',
  seller_city string COMMENT 'Seller city.',
  seller_state string COMMENT 'Two-letter Brazilian state code of the seller.'
)
COMMENT 'Historical Olist sellers. One-off backfill. Contract olist_sellers v1.0.0; contract-validated Parquet from the gate.'
PARTITIONED BY (dt string)
STORED AS PARQUET
LOCATION 's3://slussen-lake-qwer/validated/olist/sellers/'
TBLPROPERTIES (
  'projection.enabled' = 'true',
  'projection.dt.type' = 'date',
  'projection.dt.format' = 'yyyy-MM-dd',
  'projection.dt.range' = '2026-01-01,NOW',
  'projection.dt.interval' = '1',
  'projection.dt.interval.unit' = 'DAYS',
  'storage.location.template' = 's3://slussen-lake-qwer/validated/olist/sellers/dt=${dt}/'
);

CREATE EXTERNAL TABLE IF NOT EXISTS slussen_lake.ops_orders (
  event_id string COMMENT 'Unique id of this event (UUID).',
  event_type string COMMENT 'order_created, status_changed or order_canceled.',
  event_ts timestamp COMMENT 'When the event happened, UTC.',
  order_id string COMMENT 'Order identifier, stable across events.',
  order_status string COMMENT 'Order status after this event.',
  customer_id string COMMENT 'Per-order customer key (Olist semantics).',
  customer_unique_id string COMMENT 'Per-person customer key, used for repeat and cohort logic.',
  customer_zip_code_prefix string COMMENT 'Five-digit zip prefix, leading zeros kept.',
  customer_city string COMMENT 'Customer city.',
  customer_state string COMMENT 'Two-letter Brazilian state code, used to derive the market.',
  order_purchase_ts timestamp COMMENT 'Purchase time, UTC.',
  order_approved_ts timestamp COMMENT 'Payment approval time, UTC.',
  order_delivered_carrier_ts timestamp COMMENT 'Handover to carrier, UTC.',
  order_delivered_customer_ts timestamp COMMENT 'Delivery to customer, UTC.',
  order_estimated_delivery_date date COMMENT 'Promised delivery date.',
  items array<struct<order_item_id:bigint,product_id:string,seller_id:string,price:decimal(10,2),freight_value:decimal(10,2)>> COMMENT 'Order lines, at least one.',
  payments array<struct<payment_sequential:bigint,payment_type:string,payment_installments:bigint,payment_value:decimal(10,2)>> COMMENT 'Payment rows; null before payment is captured.'
)
COMMENT 'Order events from the Operations team. One record per event; an order appears once per state change. Contract ops_orders v1.0.0; contract-validated Parquet from the gate.'
PARTITIONED BY (dt string)
STORED AS PARQUET
LOCATION 's3://slussen-lake-qwer/validated/ops/orders/'
TBLPROPERTIES (
  'projection.enabled' = 'true',
  'projection.dt.type' = 'date',
  'projection.dt.format' = 'yyyy-MM-dd',
  'projection.dt.range' = '2026-01-01,NOW',
  'projection.dt.interval' = '1',
  'projection.dt.interval.unit' = 'DAYS',
  'storage.location.template' = 's3://slussen-lake-qwer/validated/ops/orders/dt=${dt}/'
);
