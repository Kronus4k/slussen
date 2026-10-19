USE ROLE DATA_ENGINEER;
USE SECONDARY ROLES NONE;
USE WAREHOUSE TRANSFORM_WH;
USE SCHEMA ECOM_DB.BRONZE;

SELECT OBJECT_CONSTRUCT(
    'orders_dup_order_id', (SELECT COUNT(*) - COUNT(DISTINCT order_id) FROM OLIST_ORDERS),
    'customers_dup_customer_id', (SELECT COUNT(*) - COUNT(DISTINCT customer_id) FROM OLIST_CUSTOMERS),
    'items_dup_order_item', (SELECT COUNT(*) - COUNT(DISTINCT order_id, order_item_id) FROM OLIST_ORDER_ITEMS),
    'payments_dup_order_seq', (SELECT COUNT(*) - COUNT(DISTINCT order_id, payment_sequential) FROM OLIST_ORDER_PAYMENTS),
    'reviews_dup_review_id', (SELECT COUNT(*) - COUNT(DISTINCT review_id) FROM OLIST_ORDER_REVIEWS),
    'reviews_dup_review_order', (SELECT COUNT(*) - COUNT(DISTINCT review_id, order_id) FROM OLIST_ORDER_REVIEWS),
    'products_dup_product_id', (SELECT COUNT(*) - COUNT(DISTINCT product_id) FROM OLIST_PRODUCTS),
    'sellers_dup_seller_id', (SELECT COUNT(*) - COUNT(DISTINCT seller_id) FROM OLIST_SELLERS),
    'translation_dup_category', (SELECT COUNT(*) - COUNT(DISTINCT product_category_name) FROM OLIST_PRODUCT_CATEGORY_NAME_TRANSLATION),
    'geo_dup_zip', (SELECT COUNT(*) - COUNT(DISTINCT geolocation_zip_code_prefix) FROM OLIST_GEOLOCATION),
    'geo_dup_full_rows', (SELECT COUNT(*) FROM OLIST_GEOLOCATION)
        - (SELECT COUNT(*) FROM (SELECT DISTINCT geolocation_zip_code_prefix, geolocation_lat, geolocation_lng, geolocation_city, geolocation_state FROM OLIST_GEOLOCATION)),
    'price_max_scale', (SELECT MAX(LENGTH(SPLIT_PART(price, '.', 2))) FROM OLIST_ORDER_ITEMS),
    'price_max_int_digits', (SELECT MAX(LENGTH(SPLIT_PART(price, '.', 1))) FROM OLIST_ORDER_ITEMS),
    'freight_max_scale', (SELECT MAX(LENGTH(SPLIT_PART(freight_value, '.', 2))) FROM OLIST_ORDER_ITEMS),
    'freight_max_int_digits', (SELECT MAX(LENGTH(SPLIT_PART(freight_value, '.', 1))) FROM OLIST_ORDER_ITEMS),
    'payment_max_scale', (SELECT MAX(LENGTH(SPLIT_PART(payment_value, '.', 2))) FROM OLIST_ORDER_PAYMENTS),
    'payment_max_int_digits', (SELECT MAX(LENGTH(SPLIT_PART(payment_value, '.', 1))) FROM OLIST_ORDER_PAYMENTS),
    'lat_max_scale', (SELECT MAX(LENGTH(SPLIT_PART(geolocation_lat, '.', 2))) FROM OLIST_GEOLOCATION),
    'lat_max_int_digits', (SELECT MAX(LENGTH(REPLACE(SPLIT_PART(geolocation_lat, '.', 1), '-', ''))) FROM OLIST_GEOLOCATION),
    'lng_max_scale', (SELECT MAX(LENGTH(SPLIT_PART(geolocation_lng, '.', 2))) FROM OLIST_GEOLOCATION),
    'lng_max_int_digits', (SELECT MAX(LENGTH(REPLACE(SPLIT_PART(geolocation_lng, '.', 1), '-', ''))) FROM OLIST_GEOLOCATION),
    'geo_exponent_values', (SELECT COUNT_IF(geolocation_lat ILIKE '%e%' OR geolocation_lng ILIKE '%e%') FROM OLIST_GEOLOCATION),
    'product_measures_with_dot', (SELECT COUNT_IF(product_name_lenght LIKE '%.%' OR product_description_lenght LIKE '%.%'
        OR product_photos_qty LIKE '%.%' OR product_weight_g LIKE '%.%' OR product_length_cm LIKE '%.%'
        OR product_height_cm LIKE '%.%' OR product_width_cm LIKE '%.%') FROM OLIST_PRODUCTS),
    'orders_bad_ts', (SELECT COUNT_IF(
           (order_purchase_timestamp IS NOT NULL AND NOT REGEXP_LIKE(order_purchase_timestamp, '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}'))
        OR (order_approved_at IS NOT NULL AND NOT REGEXP_LIKE(order_approved_at, '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}'))
        OR (order_delivered_carrier_date IS NOT NULL AND NOT REGEXP_LIKE(order_delivered_carrier_date, '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}'))
        OR (order_delivered_customer_date IS NOT NULL AND NOT REGEXP_LIKE(order_delivered_customer_date, '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}'))
        OR (order_estimated_delivery_date IS NOT NULL AND NOT REGEXP_LIKE(order_estimated_delivery_date, '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}')))
        FROM OLIST_ORDERS),
    'items_bad_ts', (SELECT COUNT_IF(shipping_limit_date IS NOT NULL AND NOT REGEXP_LIKE(shipping_limit_date, '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}')) FROM OLIST_ORDER_ITEMS),
    'reviews_bad_ts', (SELECT COUNT_IF(
           (review_creation_date IS NOT NULL AND NOT REGEXP_LIKE(review_creation_date, '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}'))
        OR (review_answer_timestamp IS NOT NULL AND NOT REGEXP_LIKE(review_answer_timestamp, '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}')))
        FROM OLIST_ORDER_REVIEWS),
    'orders_null_or_empty', (SELECT COUNT_IF(order_approved_at IS NULL OR order_approved_at = '') FROM OLIST_ORDERS)
) AS profile;