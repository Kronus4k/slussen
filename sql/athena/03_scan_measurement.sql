CREATE EXTERNAL TABLE IF NOT EXISTS slussen_lake.olist_orders_raw_csv (
  order_id string,
  customer_id string,
  order_status string,
  order_purchase_timestamp string,
  order_approved_at string,
  order_delivered_carrier_date string,
  order_delivered_customer_date string,
  order_estimated_delivery_date string
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES ('separatorChar' = ',', 'quoteChar' = '"')
STORED AS TEXTFILE
LOCATION 's3://slussen-lake-qwer/landing/olist/orders/'
TBLPROPERTIES ('skip.header.line.count' = '1');

SELECT 'csv count' AS q, count(*) AS result
FROM slussen_lake.olist_orders_raw_csv;

SELECT 'parquet count' AS q, count(*) AS result
FROM slussen_lake.olist_orders WHERE dt = '2026-10-20';

SELECT 'csv by status' AS q, order_status, count(*) AS orders
FROM slussen_lake.olist_orders_raw_csv GROUP BY order_status ORDER BY orders DESC LIMIT 3;

SELECT 'parquet by status' AS q, order_status, count(*) AS orders
FROM slussen_lake.olist_orders WHERE dt = '2026-10-20' GROUP BY order_status ORDER BY orders DESC LIMIT 3;

SELECT 'csv 2018 orders' AS q, count(*) AS result
FROM slussen_lake.olist_orders_raw_csv WHERE order_purchase_timestamp >= '2018-01-01';

SELECT 'parquet 2018 orders' AS q, count(*) AS result
FROM slussen_lake.olist_orders WHERE dt = '2026-10-20' AND order_purchase_timestamp >= TIMESTAMP '2018-01-01 00:00:00';


DROP TABLE IF EXISTS slussen_lake.olist_orders_raw_csv;