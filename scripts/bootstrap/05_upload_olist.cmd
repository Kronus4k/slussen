@echo off
set AWS_PROFILE=slussen-de
set AWS_REGION=eu-north-1
set BUCKET=slussen-lake-qwer
set SRC=..\data\olist
set DEST=s3://%BUCKET%/landing/olist

aws s3 cp %SRC%\olist_customers_dataset.csv %DEST%/customers/
aws s3 cp %SRC%\olist_geolocation_dataset.csv %DEST%/geolocation/
aws s3 cp %SRC%\olist_orders_dataset.csv %DEST%/orders/
aws s3 cp %SRC%\olist_order_items_dataset.csv %DEST%/order_items/
aws s3 cp %SRC%\olist_order_payments_dataset.csv %DEST%/order_payments/
aws s3 cp %SRC%\olist_order_reviews_dataset.csv %DEST%/order_reviews/
aws s3 cp %SRC%\olist_products_dataset.csv %DEST%/products/
aws s3 cp %SRC%\olist_sellers_dataset.csv %DEST%/sellers/
aws s3 cp %SRC%\product_category_name_translation.csv %DEST%/product_category_name_translation/

aws s3 ls %DEST%/ --recursive --human-readable --summarize