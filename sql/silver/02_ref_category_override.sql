USE ROLE DATA_ENGINEER;
USE WAREHOUSE TRANSFORM_WH;

CREATE TABLE IF NOT EXISTS ECOM_DB.SILVER.REF_CATEGORY_OVERRIDE (
  product_category_name VARCHAR NOT NULL,
  product_category_name_english VARCHAR NOT NULL,
  CONSTRAINT pk_ref_category_override PRIMARY KEY (product_category_name)
);

MERGE INTO ECOM_DB.SILVER.REF_CATEGORY_OVERRIDE t
USING (
  SELECT column1 AS product_category_name, column2 AS product_category_name_english
  FROM VALUES
    ('pc_gamer', 'pc_gamer'),
    ('portateis_cozinha_e_preparadores_de_alimentos', 'portable_kitchen_food_preparers')
) s
ON t.product_category_name = s.product_category_name
WHEN MATCHED AND t.product_category_name_english <> s.product_category_name_english
  THEN UPDATE SET product_category_name_english = s.product_category_name_english
WHEN NOT MATCHED
  THEN INSERT (product_category_name, product_category_name_english) VALUES (s.product_category_name, s.product_category_name_english);