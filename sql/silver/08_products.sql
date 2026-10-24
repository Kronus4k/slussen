USE ROLE DATA_ENGINEER;
USE WAREHOUSE TRANSFORM_WH;

CREATE OR REPLACE DYNAMIC TABLE ECOM_DB.SILVER.PRODUCTS
  TARGET_LAG = 'DOWNSTREAM'
  WAREHOUSE = TRANSFORM_WH
  REFRESH_MODE = AUTO
AS
SELECT
  p.product_id,
  p.product_category_name AS category_name_pt,
  COALESCE(t.product_category_name_english, o.product_category_name_english, IFF(p.product_category_name IS NULL, 'unknown', p.product_category_name)) AS category_name_en,
  CASE
    WHEN t.product_category_name_english IS NOT NULL THEN 'translation'
    WHEN o.product_category_name_english IS NOT NULL THEN 'override'
    WHEN p.product_category_name IS NULL THEN 'unknown'
    ELSE 'portuguese_fallback'
  END AS category_source,
  p.product_name_lenght AS product_name_length,
  p.product_description_lenght AS product_description_length,
  p.product_photos_qty,
  p.product_weight_g,
  p.product_length_cm,
  p.product_height_cm,
  p.product_width_cm,
  p._file_name AS source_file,
  p._loaded_at
FROM ECOM_DB.BRONZE.OLIST_PRODUCTS p
LEFT JOIN ECOM_DB.BRONZE.OLIST_PRODUCT_CATEGORY_NAME_TRANSLATION t ON t.product_category_name = p.product_category_name
LEFT JOIN ECOM_DB.SILVER.REF_CATEGORY_OVERRIDE o ON o.product_category_name = p.product_category_name;