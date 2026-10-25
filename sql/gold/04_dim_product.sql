USE ROLE DATA_ENGINEER;

CREATE OR REPLACE DYNAMIC TABLE ECOM_DB.GOLD.DIM_PRODUCT
  TARGET_LAG = '12 hours'
  WAREHOUSE = TRANSFORM_WH
  REFRESH_MODE = AUTO
AS
SELECT
  product_id,
  category_name_en AS category,
  category_name_pt,
  category_source,
  product_weight_g,
  product_length_cm,
  product_height_cm,
  product_width_cm
FROM ECOM_DB.SILVER.PRODUCTS
UNION ALL
SELECT 'unknown', 'unknown', NULL, 'unknown_member', NULL, NULL, NULL, NULL;