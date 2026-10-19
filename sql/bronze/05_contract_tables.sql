USE ROLE DATA_ENGINEER;
USE SECONDARY ROLES NONE;
USE WAREHOUSE LOAD_WH;
USE SCHEMA ECOM_DB.BRONZE;

CREATE TABLE IF NOT EXISTS ECOM_DB.BRONZE.FINANCE_SETTLEMENTS (
    settlement_id VARCHAR NOT NULL COMMENT 'Unique settlement row id.',
    payout_batch_id VARCHAR NOT NULL COMMENT 'Weekly payout batch this row belongs to.',
    order_id VARCHAR NOT NULL COMMENT 'Order the payment belongs to.',
    payment_sequential NUMBER(38,0) NOT NULL COMMENT 'Payment row number within the order.',
    payment_type VARCHAR NOT NULL COMMENT 'Payment method.',
    gross_amount NUMBER(12,2) NOT NULL COMMENT 'Amount paid by the customer in BRL.',
    fee_amount NUMBER(12,2) NOT NULL COMMENT 'Processing fee in BRL.',
    net_amount NUMBER(12,2) NOT NULL COMMENT 'Amount paid out, gross minus fee.',
    currency VARCHAR NOT NULL COMMENT 'ISO 4217 code, BRL.',
    payment_date DATE NOT NULL COMMENT 'Date the customer paid.',
    settlement_date DATE COMMENT 'Date the money was paid out; null while pending.',
    settlement_status VARCHAR NOT NULL COMMENT 'settled, pending or disputed.',
    generated_at TIMESTAMP_TZ NOT NULL COMMENT 'When Finance produced the file, UTC.',
    _file_name VARCHAR,
    _file_row_number NUMBER(38,0),
    _loaded_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
    _source_team VARCHAR
)
COMMENT = 'Weekly payment settlements from the Finance team. One record per settled payment row. Contract finance_settlements v1.0.0; loaded by Snowpipe from validated/finance/settlements/.';

CREATE PIPE IF NOT EXISTS ECOM_DB.BRONZE.PIPE_FINANCE_SETTLEMENTS
    AUTO_INGEST = TRUE
    COMMENT = 'Loads contract finance_settlements from validated/finance/settlements/ into FINANCE_SETTLEMENTS.'
AS
COPY INTO ECOM_DB.BRONZE.FINANCE_SETTLEMENTS (
    settlement_id,
    payout_batch_id,
    order_id,
    payment_sequential,
    payment_type,
    gross_amount,
    fee_amount,
    net_amount,
    currency,
    payment_date,
    settlement_date,
    settlement_status,
    generated_at,
    _file_name,
    _file_row_number,
    _loaded_at,
    _source_team
)
FROM (
    SELECT
        $1:settlement_id::VARCHAR,
        $1:payout_batch_id::VARCHAR,
        $1:order_id::VARCHAR,
        $1:payment_sequential::NUMBER(38,0),
        $1:payment_type::VARCHAR,
        $1:gross_amount::NUMBER(12,2),
        $1:fee_amount::NUMBER(12,2),
        $1:net_amount::NUMBER(12,2),
        $1:currency::VARCHAR,
        $1:payment_date::DATE,
        $1:settlement_date::DATE,
        $1:settlement_status::VARCHAR,
        TO_TIMESTAMP_TZ(TO_VARCHAR($1:generated_at::TIMESTAMP_NTZ, 'YYYY-MM-DD HH24:MI:SS.FF6') || ' +00:00', 'YYYY-MM-DD HH24:MI:SS.FF6 TZH:TZM'),
        METADATA$FILENAME,
        METADATA$FILE_ROW_NUMBER,
        CURRENT_TIMESTAMP(),
        'finance'
    FROM @ECOM_DB.BRONZE.STG_VALIDATED/finance/settlements/
)
PATTERN = '.*[.]parquet'
FILE_FORMAT = (FORMAT_NAME = 'ECOM_DB.BRONZE.FF_PARQUET');

CREATE TABLE IF NOT EXISTS ECOM_DB.BRONZE.OLIST_CUSTOMERS (
    customer_id VARCHAR NOT NULL COMMENT 'Per-order customer key (Olist semantics).',
    customer_unique_id VARCHAR NOT NULL COMMENT 'Per-person customer key, used for repeat and cohort logic.',
    customer_zip_code_prefix VARCHAR NOT NULL COMMENT 'Five-digit zip prefix, leading zeros kept.',
    customer_city VARCHAR NOT NULL COMMENT 'Customer city.',
    customer_state VARCHAR NOT NULL COMMENT 'Two-letter Brazilian state code, used to derive the market.',
    _file_name VARCHAR,
    _file_row_number NUMBER(38,0),
    _loaded_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
    _source_team VARCHAR
)
COMMENT = 'Historical Olist customers, one row per order-level customer id. One-off backfill. Contract olist_customers v1.0.0; loaded by Snowpipe from validated/olist/customers/.';

CREATE PIPE IF NOT EXISTS ECOM_DB.BRONZE.PIPE_OLIST_CUSTOMERS
    AUTO_INGEST = TRUE
    COMMENT = 'Loads contract olist_customers from validated/olist/customers/ into OLIST_CUSTOMERS.'
AS
COPY INTO ECOM_DB.BRONZE.OLIST_CUSTOMERS (
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state,
    _file_name,
    _file_row_number,
    _loaded_at,
    _source_team
)
FROM (
    SELECT
        $1:customer_id::VARCHAR,
        $1:customer_unique_id::VARCHAR,
        $1:customer_zip_code_prefix::VARCHAR,
        $1:customer_city::VARCHAR,
        $1:customer_state::VARCHAR,
        METADATA$FILENAME,
        METADATA$FILE_ROW_NUMBER,
        CURRENT_TIMESTAMP(),
        'data-platform'
    FROM @ECOM_DB.BRONZE.STG_VALIDATED/olist/customers/
)
PATTERN = '.*[.]parquet'
FILE_FORMAT = (FORMAT_NAME = 'ECOM_DB.BRONZE.FF_PARQUET');

CREATE TABLE IF NOT EXISTS ECOM_DB.BRONZE.OLIST_GEOLOCATION (
    geolocation_zip_code_prefix VARCHAR NOT NULL COMMENT 'Five-digit zip prefix, leading zeros kept.',
    geolocation_lat NUMBER(24,20) NOT NULL COMMENT 'Latitude as sent, up to 20 decimals.',
    geolocation_lng NUMBER(24,20) NOT NULL COMMENT 'Longitude as sent, up to 20 decimals.',
    geolocation_city VARCHAR NOT NULL COMMENT 'City name as sent; spelling varies.',
    geolocation_state VARCHAR NOT NULL COMMENT 'Two-letter Brazilian state code.',
    _file_name VARCHAR,
    _file_row_number NUMBER(38,0),
    _loaded_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
    _source_team VARCHAR
)
COMMENT = 'Historical Olist zip-code coordinates. The source has no key (about 262k exact duplicate rows), so primary_key is empty and rows land as sent. One-off backfill. Contract olist_geolocation v1.0.0; loaded by Snowpipe from validated/olist/geolocation/.';

CREATE PIPE IF NOT EXISTS ECOM_DB.BRONZE.PIPE_OLIST_GEOLOCATION
    AUTO_INGEST = TRUE
    COMMENT = 'Loads contract olist_geolocation from validated/olist/geolocation/ into OLIST_GEOLOCATION.'
AS
COPY INTO ECOM_DB.BRONZE.OLIST_GEOLOCATION (
    geolocation_zip_code_prefix,
    geolocation_lat,
    geolocation_lng,
    geolocation_city,
    geolocation_state,
    _file_name,
    _file_row_number,
    _loaded_at,
    _source_team
)
FROM (
    SELECT
        $1:geolocation_zip_code_prefix::VARCHAR,
        $1:geolocation_lat::NUMBER(24,20),
        $1:geolocation_lng::NUMBER(24,20),
        $1:geolocation_city::VARCHAR,
        $1:geolocation_state::VARCHAR,
        METADATA$FILENAME,
        METADATA$FILE_ROW_NUMBER,
        CURRENT_TIMESTAMP(),
        'data-platform'
    FROM @ECOM_DB.BRONZE.STG_VALIDATED/olist/geolocation/
)
PATTERN = '.*[.]parquet'
FILE_FORMAT = (FORMAT_NAME = 'ECOM_DB.BRONZE.FF_PARQUET');

CREATE TABLE IF NOT EXISTS ECOM_DB.BRONZE.OLIST_ORDER_ITEMS (
    order_id VARCHAR NOT NULL COMMENT 'Order identifier.',
    order_item_id NUMBER(38,0) NOT NULL COMMENT 'Line number within the order, starting at 1.',
    product_id VARCHAR NOT NULL COMMENT 'Product identifier.',
    seller_id VARCHAR NOT NULL COMMENT 'Seller identifier.',
    shipping_limit_date TIMESTAMP_NTZ NOT NULL COMMENT 'Latest handover time for the seller, source local time without zone.',
    price NUMBER(10,2) NOT NULL COMMENT 'Item price in BRL.',
    freight_value NUMBER(10,2) NOT NULL COMMENT 'Freight charged for the item in BRL.',
    _file_name VARCHAR,
    _file_row_number NUMBER(38,0),
    _loaded_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
    _source_team VARCHAR
)
COMMENT = 'Historical Olist order lines, one row per item in an order. One-off backfill. Contract olist_order_items v1.0.0; loaded by Snowpipe from validated/olist/order_items/.';

CREATE PIPE IF NOT EXISTS ECOM_DB.BRONZE.PIPE_OLIST_ORDER_ITEMS
    AUTO_INGEST = TRUE
    COMMENT = 'Loads contract olist_order_items from validated/olist/order_items/ into OLIST_ORDER_ITEMS.'
AS
COPY INTO ECOM_DB.BRONZE.OLIST_ORDER_ITEMS (
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date,
    price,
    freight_value,
    _file_name,
    _file_row_number,
    _loaded_at,
    _source_team
)
FROM (
    SELECT
        $1:order_id::VARCHAR,
        $1:order_item_id::NUMBER(38,0),
        $1:product_id::VARCHAR,
        $1:seller_id::VARCHAR,
        TO_TIMESTAMP_NTZ($1:shipping_limit_date::NUMBER, 6),
        $1:price::NUMBER(10,2),
        $1:freight_value::NUMBER(10,2),
        METADATA$FILENAME,
        METADATA$FILE_ROW_NUMBER,
        CURRENT_TIMESTAMP(),
        'data-platform'
    FROM @ECOM_DB.BRONZE.STG_VALIDATED/olist/order_items/
)
PATTERN = '.*[.]parquet'
FILE_FORMAT = (FORMAT_NAME = 'ECOM_DB.BRONZE.FF_PARQUET');

CREATE TABLE IF NOT EXISTS ECOM_DB.BRONZE.OLIST_ORDER_PAYMENTS (
    order_id VARCHAR NOT NULL COMMENT 'Order identifier.',
    payment_sequential NUMBER(38,0) NOT NULL COMMENT 'Payment row number within the order.',
    payment_type VARCHAR NOT NULL COMMENT 'credit_card, boleto, voucher, debit_card or not_defined.',
    payment_installments NUMBER(38,0) NOT NULL COMMENT 'Number of installments.',
    payment_value NUMBER(10,2) NOT NULL COMMENT 'Amount of this payment row in BRL.',
    _file_name VARCHAR,
    _file_row_number NUMBER(38,0),
    _loaded_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
    _source_team VARCHAR
)
COMMENT = 'Historical Olist payment rows; an order can have several. One-off backfill. Contract olist_order_payments v1.0.0; loaded by Snowpipe from validated/olist/order_payments/.';

CREATE PIPE IF NOT EXISTS ECOM_DB.BRONZE.PIPE_OLIST_ORDER_PAYMENTS
    AUTO_INGEST = TRUE
    COMMENT = 'Loads contract olist_order_payments from validated/olist/order_payments/ into OLIST_ORDER_PAYMENTS.'
AS
COPY INTO ECOM_DB.BRONZE.OLIST_ORDER_PAYMENTS (
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value,
    _file_name,
    _file_row_number,
    _loaded_at,
    _source_team
)
FROM (
    SELECT
        $1:order_id::VARCHAR,
        $1:payment_sequential::NUMBER(38,0),
        $1:payment_type::VARCHAR,
        $1:payment_installments::NUMBER(38,0),
        $1:payment_value::NUMBER(10,2),
        METADATA$FILENAME,
        METADATA$FILE_ROW_NUMBER,
        CURRENT_TIMESTAMP(),
        'data-platform'
    FROM @ECOM_DB.BRONZE.STG_VALIDATED/olist/order_payments/
)
PATTERN = '.*[.]parquet'
FILE_FORMAT = (FORMAT_NAME = 'ECOM_DB.BRONZE.FF_PARQUET');

CREATE TABLE IF NOT EXISTS ECOM_DB.BRONZE.OLIST_ORDER_REVIEWS (
    review_id VARCHAR NOT NULL COMMENT 'Review identifier; not unique on its own.',
    order_id VARCHAR NOT NULL COMMENT 'Order the review belongs to.',
    review_score NUMBER(38,0) NOT NULL COMMENT 'Score from 1 to 5.',
    review_comment_title VARCHAR COMMENT 'Free-text title written by the customer, Portuguese.',
    review_comment_message VARCHAR COMMENT 'Free-text comment written by the customer, Portuguese; may contain line breaks.',
    review_creation_date TIMESTAMP_NTZ NOT NULL COMMENT 'When the review survey was sent, source local time without zone.',
    review_answer_timestamp TIMESTAMP_NTZ NOT NULL COMMENT 'When the customer answered, source local time without zone.',
    _file_name VARCHAR,
    _file_row_number NUMBER(38,0),
    _loaded_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
    _source_team VARCHAR
)
COMMENT = 'Historical Olist customer reviews. review_id alone repeats across orders, so the key is review_id plus order_id. One-off backfill. Contract olist_order_reviews v1.0.0; loaded by Snowpipe from validated/olist/order_reviews/.';

CREATE PIPE IF NOT EXISTS ECOM_DB.BRONZE.PIPE_OLIST_ORDER_REVIEWS
    AUTO_INGEST = TRUE
    COMMENT = 'Loads contract olist_order_reviews from validated/olist/order_reviews/ into OLIST_ORDER_REVIEWS.'
AS
COPY INTO ECOM_DB.BRONZE.OLIST_ORDER_REVIEWS (
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp,
    _file_name,
    _file_row_number,
    _loaded_at,
    _source_team
)
FROM (
    SELECT
        $1:review_id::VARCHAR,
        $1:order_id::VARCHAR,
        $1:review_score::NUMBER(38,0),
        $1:review_comment_title::VARCHAR,
        $1:review_comment_message::VARCHAR,
        TO_TIMESTAMP_NTZ($1:review_creation_date::NUMBER, 6),
        TO_TIMESTAMP_NTZ($1:review_answer_timestamp::NUMBER, 6),
        METADATA$FILENAME,
        METADATA$FILE_ROW_NUMBER,
        CURRENT_TIMESTAMP(),
        'data-platform'
    FROM @ECOM_DB.BRONZE.STG_VALIDATED/olist/order_reviews/
)
PATTERN = '.*[.]parquet'
FILE_FORMAT = (FORMAT_NAME = 'ECOM_DB.BRONZE.FF_PARQUET');

CREATE TABLE IF NOT EXISTS ECOM_DB.BRONZE.OLIST_ORDERS (
    order_id VARCHAR NOT NULL COMMENT 'Order identifier.',
    customer_id VARCHAR NOT NULL COMMENT 'Per-order customer key; join to olist_customers.',
    order_status VARCHAR NOT NULL COMMENT 'Final order status, e.g. delivered, shipped, canceled, unavailable.',
    order_purchase_timestamp TIMESTAMP_NTZ NOT NULL COMMENT 'Purchase time, source local time without zone.',
    order_approved_at TIMESTAMP_NTZ COMMENT 'Payment approval time, source local time without zone.',
    order_delivered_carrier_date TIMESTAMP_NTZ COMMENT 'Handover to carrier, source local time without zone.',
    order_delivered_customer_date TIMESTAMP_NTZ COMMENT 'Delivery to customer, source local time without zone.',
    order_estimated_delivery_date TIMESTAMP_NTZ NOT NULL COMMENT 'Promised delivery date, sent as a timestamp at midnight.',
    _file_name VARCHAR,
    _file_row_number NUMBER(38,0),
    _loaded_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
    _source_team VARCHAR
)
COMMENT = 'Historical Olist orders, one row per order. One-off backfill from the public Olist dataset. Contract olist_orders v1.0.0; loaded by Snowpipe from validated/olist/orders/.';

CREATE PIPE IF NOT EXISTS ECOM_DB.BRONZE.PIPE_OLIST_ORDERS
    AUTO_INGEST = TRUE
    COMMENT = 'Loads contract olist_orders from validated/olist/orders/ into OLIST_ORDERS.'
AS
COPY INTO ECOM_DB.BRONZE.OLIST_ORDERS (
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date,
    _file_name,
    _file_row_number,
    _loaded_at,
    _source_team
)
FROM (
    SELECT
        $1:order_id::VARCHAR,
        $1:customer_id::VARCHAR,
        $1:order_status::VARCHAR,
        TO_TIMESTAMP_NTZ($1:order_purchase_timestamp::NUMBER, 6),
        TO_TIMESTAMP_NTZ($1:order_approved_at::NUMBER, 6),
        TO_TIMESTAMP_NTZ($1:order_delivered_carrier_date::NUMBER, 6),
        TO_TIMESTAMP_NTZ($1:order_delivered_customer_date::NUMBER, 6),
        TO_TIMESTAMP_NTZ($1:order_estimated_delivery_date::NUMBER, 6),
        METADATA$FILENAME,
        METADATA$FILE_ROW_NUMBER,
        CURRENT_TIMESTAMP(),
        'data-platform'
    FROM @ECOM_DB.BRONZE.STG_VALIDATED/olist/orders/
)
PATTERN = '.*[.]parquet'
FILE_FORMAT = (FORMAT_NAME = 'ECOM_DB.BRONZE.FF_PARQUET');

CREATE TABLE IF NOT EXISTS ECOM_DB.BRONZE.OLIST_PRODUCT_CATEGORY_NAME_TRANSLATION (
    product_category_name VARCHAR NOT NULL COMMENT 'Category name in Portuguese.',
    product_category_name_english VARCHAR NOT NULL COMMENT 'Category name in English.',
    _file_name VARCHAR,
    _file_row_number NUMBER(38,0),
    _loaded_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
    _source_team VARCHAR
)
COMMENT = 'Portuguese to English product category names from the Olist dataset. Two categories are missing. One-off backfill. Contract olist_product_category_name_translation v1.0.0; loaded by Snowpipe from validated/olist/product_category_name_translation/.';

CREATE PIPE IF NOT EXISTS ECOM_DB.BRONZE.PIPE_OLIST_PRODUCT_CATEGORY_NAME_TRANSLATION
    AUTO_INGEST = TRUE
    COMMENT = 'Loads contract olist_product_category_name_translation from validated/olist/product_category_name_translation/ into OLIST_PRODUCT_CATEGORY_NAME_TRANSLATION.'
AS
COPY INTO ECOM_DB.BRONZE.OLIST_PRODUCT_CATEGORY_NAME_TRANSLATION (
    product_category_name,
    product_category_name_english,
    _file_name,
    _file_row_number,
    _loaded_at,
    _source_team
)
FROM (
    SELECT
        $1:product_category_name::VARCHAR,
        $1:product_category_name_english::VARCHAR,
        METADATA$FILENAME,
        METADATA$FILE_ROW_NUMBER,
        CURRENT_TIMESTAMP(),
        'data-platform'
    FROM @ECOM_DB.BRONZE.STG_VALIDATED/olist/product_category_name_translation/
)
PATTERN = '.*[.]parquet'
FILE_FORMAT = (FORMAT_NAME = 'ECOM_DB.BRONZE.FF_PARQUET');

CREATE TABLE IF NOT EXISTS ECOM_DB.BRONZE.OLIST_PRODUCTS (
    product_id VARCHAR NOT NULL COMMENT 'Product identifier.',
    product_category_name VARCHAR COMMENT 'Category in Portuguese; null for about 610 products.',
    product_name_lenght NUMBER(38,0) COMMENT 'Characters in the product name (source spelling).',
    product_description_lenght NUMBER(38,0) COMMENT 'Characters in the product description (source spelling).',
    product_photos_qty NUMBER(38,0) COMMENT 'Number of product photos.',
    product_weight_g NUMBER(38,0) COMMENT 'Weight in grams.',
    product_length_cm NUMBER(38,0) COMMENT 'Length in centimetres.',
    product_height_cm NUMBER(38,0) COMMENT 'Height in centimetres.',
    product_width_cm NUMBER(38,0) COMMENT 'Width in centimetres.',
    _file_name VARCHAR,
    _file_row_number NUMBER(38,0),
    _loaded_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
    _source_team VARCHAR
)
COMMENT = 'Historical Olist product catalogue. Column names keep the source spelling (lenght). One-off backfill. Contract olist_products v1.0.0; loaded by Snowpipe from validated/olist/products/.';

CREATE PIPE IF NOT EXISTS ECOM_DB.BRONZE.PIPE_OLIST_PRODUCTS
    AUTO_INGEST = TRUE
    COMMENT = 'Loads contract olist_products from validated/olist/products/ into OLIST_PRODUCTS.'
AS
COPY INTO ECOM_DB.BRONZE.OLIST_PRODUCTS (
    product_id,
    product_category_name,
    product_name_lenght,
    product_description_lenght,
    product_photos_qty,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm,
    _file_name,
    _file_row_number,
    _loaded_at,
    _source_team
)
FROM (
    SELECT
        $1:product_id::VARCHAR,
        $1:product_category_name::VARCHAR,
        $1:product_name_lenght::NUMBER(38,0),
        $1:product_description_lenght::NUMBER(38,0),
        $1:product_photos_qty::NUMBER(38,0),
        $1:product_weight_g::NUMBER(38,0),
        $1:product_length_cm::NUMBER(38,0),
        $1:product_height_cm::NUMBER(38,0),
        $1:product_width_cm::NUMBER(38,0),
        METADATA$FILENAME,
        METADATA$FILE_ROW_NUMBER,
        CURRENT_TIMESTAMP(),
        'data-platform'
    FROM @ECOM_DB.BRONZE.STG_VALIDATED/olist/products/
)
PATTERN = '.*[.]parquet'
FILE_FORMAT = (FORMAT_NAME = 'ECOM_DB.BRONZE.FF_PARQUET');

CREATE TABLE IF NOT EXISTS ECOM_DB.BRONZE.OLIST_SELLERS (
    seller_id VARCHAR NOT NULL COMMENT 'Seller identifier.',
    seller_zip_code_prefix VARCHAR NOT NULL COMMENT 'Five-digit zip prefix of the seller (a business), leading zeros kept.',
    seller_city VARCHAR NOT NULL COMMENT 'Seller city.',
    seller_state VARCHAR NOT NULL COMMENT 'Two-letter Brazilian state code of the seller.',
    _file_name VARCHAR,
    _file_row_number NUMBER(38,0),
    _loaded_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
    _source_team VARCHAR
)
COMMENT = 'Historical Olist sellers. One-off backfill. Contract olist_sellers v1.0.0; loaded by Snowpipe from validated/olist/sellers/.';

CREATE PIPE IF NOT EXISTS ECOM_DB.BRONZE.PIPE_OLIST_SELLERS
    AUTO_INGEST = TRUE
    COMMENT = 'Loads contract olist_sellers from validated/olist/sellers/ into OLIST_SELLERS.'
AS
COPY INTO ECOM_DB.BRONZE.OLIST_SELLERS (
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state,
    _file_name,
    _file_row_number,
    _loaded_at,
    _source_team
)
FROM (
    SELECT
        $1:seller_id::VARCHAR,
        $1:seller_zip_code_prefix::VARCHAR,
        $1:seller_city::VARCHAR,
        $1:seller_state::VARCHAR,
        METADATA$FILENAME,
        METADATA$FILE_ROW_NUMBER,
        CURRENT_TIMESTAMP(),
        'data-platform'
    FROM @ECOM_DB.BRONZE.STG_VALIDATED/olist/sellers/
)
PATTERN = '.*[.]parquet'
FILE_FORMAT = (FORMAT_NAME = 'ECOM_DB.BRONZE.FF_PARQUET');

CREATE TABLE IF NOT EXISTS ECOM_DB.BRONZE.OPS_ORDERS (
    event_id VARCHAR NOT NULL COMMENT 'Unique id of this event (UUID).',
    event_type VARCHAR NOT NULL COMMENT 'order_created, status_changed or order_canceled.',
    event_ts TIMESTAMP_TZ NOT NULL COMMENT 'When the event happened, UTC.',
    order_id VARCHAR NOT NULL COMMENT 'Order identifier, stable across events.',
    order_status VARCHAR NOT NULL COMMENT 'Order status after this event.',
    customer_id VARCHAR NOT NULL COMMENT 'Per-order customer key (Olist semantics).',
    customer_unique_id VARCHAR NOT NULL COMMENT 'Per-person customer key, used for repeat and cohort logic.',
    customer_zip_code_prefix VARCHAR NOT NULL COMMENT 'Five-digit zip prefix, leading zeros kept.',
    customer_city VARCHAR NOT NULL COMMENT 'Customer city.',
    customer_state VARCHAR NOT NULL COMMENT 'Two-letter Brazilian state code, used to derive the market.',
    order_purchase_ts TIMESTAMP_TZ NOT NULL COMMENT 'Purchase time, UTC.',
    order_approved_ts TIMESTAMP_TZ COMMENT 'Payment approval time, UTC.',
    order_delivered_carrier_ts TIMESTAMP_TZ COMMENT 'Handover to carrier, UTC.',
    order_delivered_customer_ts TIMESTAMP_TZ COMMENT 'Delivery to customer, UTC.',
    order_estimated_delivery_date DATE NOT NULL COMMENT 'Promised delivery date.',
    items VARIANT NOT NULL COMMENT 'Order lines, at least one.',
    payments VARIANT COMMENT 'Payment rows; null before payment is captured.',
    _file_name VARCHAR,
    _file_row_number NUMBER(38,0),
    _loaded_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
    _source_team VARCHAR
)
COMMENT = 'Order events from the Operations team. One record per event; an order appears once per state change. Contract ops_orders v1.0.0; loaded by Snowpipe from validated/ops/orders/.';

CREATE PIPE IF NOT EXISTS ECOM_DB.BRONZE.PIPE_OPS_ORDERS
    AUTO_INGEST = TRUE
    COMMENT = 'Loads contract ops_orders from validated/ops/orders/ into OPS_ORDERS.'
AS
COPY INTO ECOM_DB.BRONZE.OPS_ORDERS (
    event_id,
    event_type,
    event_ts,
    order_id,
    order_status,
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state,
    order_purchase_ts,
    order_approved_ts,
    order_delivered_carrier_ts,
    order_delivered_customer_ts,
    order_estimated_delivery_date,
    items,
    payments,
    _file_name,
    _file_row_number,
    _loaded_at,
    _source_team
)
FROM (
    SELECT
        $1:event_id::VARCHAR,
        $1:event_type::VARCHAR,
        TO_TIMESTAMP_TZ(TO_VARCHAR($1:event_ts::TIMESTAMP_NTZ, 'YYYY-MM-DD HH24:MI:SS.FF6') || ' +00:00', 'YYYY-MM-DD HH24:MI:SS.FF6 TZH:TZM'),
        $1:order_id::VARCHAR,
        $1:order_status::VARCHAR,
        $1:customer_id::VARCHAR,
        $1:customer_unique_id::VARCHAR,
        $1:customer_zip_code_prefix::VARCHAR,
        $1:customer_city::VARCHAR,
        $1:customer_state::VARCHAR,
        TO_TIMESTAMP_TZ(TO_VARCHAR($1:order_purchase_ts::TIMESTAMP_NTZ, 'YYYY-MM-DD HH24:MI:SS.FF6') || ' +00:00', 'YYYY-MM-DD HH24:MI:SS.FF6 TZH:TZM'),
        TO_TIMESTAMP_TZ(TO_VARCHAR($1:order_approved_ts::TIMESTAMP_NTZ, 'YYYY-MM-DD HH24:MI:SS.FF6') || ' +00:00', 'YYYY-MM-DD HH24:MI:SS.FF6 TZH:TZM'),
        TO_TIMESTAMP_TZ(TO_VARCHAR($1:order_delivered_carrier_ts::TIMESTAMP_NTZ, 'YYYY-MM-DD HH24:MI:SS.FF6') || ' +00:00', 'YYYY-MM-DD HH24:MI:SS.FF6 TZH:TZM'),
        TO_TIMESTAMP_TZ(TO_VARCHAR($1:order_delivered_customer_ts::TIMESTAMP_NTZ, 'YYYY-MM-DD HH24:MI:SS.FF6') || ' +00:00', 'YYYY-MM-DD HH24:MI:SS.FF6 TZH:TZM'),
        $1:order_estimated_delivery_date::DATE,
        $1:items,
        $1:payments,
        METADATA$FILENAME,
        METADATA$FILE_ROW_NUMBER,
        CURRENT_TIMESTAMP(),
        'operations'
    FROM @ECOM_DB.BRONZE.STG_VALIDATED/ops/orders/
)
PATTERN = '.*[.]parquet'
FILE_FORMAT = (FORMAT_NAME = 'ECOM_DB.BRONZE.FF_PARQUET');
