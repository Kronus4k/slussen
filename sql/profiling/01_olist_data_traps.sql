USE SECONDARY ROLES NONE;
USE ROLE DATA_ENGINEER;
USE WAREHOUSE TRANSFORM_WH;
USE SCHEMA ECOM_DB.BRONZE;

SELECT COUNT(*) AS customer_rows,
       COUNT(DISTINCT customer_id) AS distinct_customer_id,
       COUNT(DISTINCT customer_unique_id) AS distinct_customer_unique_id,
       (SELECT COUNT(*) FROM (SELECT customer_unique_id FROM OLIST_CUSTOMERS
                              GROUP BY 1 HAVING COUNT(*) > 1)) AS people_with_2plus_ids
FROM OLIST_CUSTOMERS;

WITH pay AS (SELECT order_id, COUNT(*) AS n FROM OLIST_ORDER_PAYMENTS GROUP BY 1)
SELECT COUNT(*) AS orders_with_payments,
       COUNT_IF(n > 1) AS orders_with_2plus_payment_rows,
       MAX(n) AS max_payment_rows_per_order,
       (SELECT SUM(price::NUMBER(12,2)) FROM OLIST_ORDER_ITEMS) AS item_value_correct,
       (SELECT SUM(i.price::NUMBER(12,2)) FROM OLIST_ORDER_ITEMS i
          JOIN OLIST_ORDER_PAYMENTS p ON p.order_id = i.order_id) AS item_value_naive_join
FROM pay;

SELECT order_status, COUNT(*) AS orders
FROM OLIST_ORDERS
GROUP BY 1
ORDER BY 2 DESC;

SELECT COUNT_IF(p.product_category_name IS NULL) AS products_without_category,
       COUNT(DISTINCT IFF(p.product_category_name IS NOT NULL AND t.product_category_name IS NULL,
                          p.product_category_name, NULL)) AS categories_without_translation,
       LISTAGG(DISTINCT IFF(p.product_category_name IS NOT NULL AND t.product_category_name IS NULL,
                            p.product_category_name, NULL), ', ') AS untranslated_categories
FROM OLIST_PRODUCTS p
LEFT JOIN OLIST_PRODUCT_CATEGORY_NAME_TRANSLATION t
  ON t.product_category_name = p.product_category_name;

SELECT DATE_TRUNC('month', order_purchase_timestamp::TIMESTAMP_NTZ)::DATE AS month,
       COUNT(*) AS orders
FROM OLIST_ORDERS
GROUP BY 1
ORDER BY 1;

SELECT COUNT_IF(LEFT(customer_zip_code_prefix, 1) = '0') AS zips_with_leading_zero,
       COUNT_IF(LENGTH(customer_zip_code_prefix) <> 5) AS zips_not_5_chars,
       COUNT(*) AS customers
FROM OLIST_CUSTOMERS;