USE ROLE DATA_ENGINEER;

CREATE OR REPLACE DYNAMIC TABLE ECOM_DB.GOLD.DIM_PRODUCT
  TARGET_LAG = '12 hours'
  WAREHOUSE = TRANSFORM_WH
  REFRESH_MODE = AUTO
AS
SELECT
  p.product_id,
  p.category,
  COALESCE(l.category_label, INITCAP(REPLACE(p.category, '_', ' '))) AS category_label,
  p.category_name_pt,
  p.category_source,
  p.product_weight_g,
  p.product_length_cm,
  p.product_height_cm,
  p.product_width_cm
FROM (
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
  SELECT 'unknown', 'unknown', NULL, 'unknown_member', NULL, NULL, NULL, NULL
) p
LEFT JOIN ECOM_DB.SILVER.REF_CATEGORY_LABEL l
  ON l.category = p.category;