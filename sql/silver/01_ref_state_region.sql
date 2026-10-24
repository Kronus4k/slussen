USE ROLE DATA_ENGINEER;
USE WAREHOUSE TRANSFORM_WH;

CREATE TABLE IF NOT EXISTS ECOM_DB.SILVER.REF_STATE_REGION (
  state_code VARCHAR(2) NOT NULL,
  region_name VARCHAR NOT NULL,
  market_code VARCHAR NOT NULL,
  CONSTRAINT pk_ref_state_region PRIMARY KEY (state_code)
);

MERGE INTO ECOM_DB.SILVER.REF_STATE_REGION t
USING (
  SELECT column1 AS state_code, column2 AS region_name, column3 AS market_code
  FROM VALUES
    ('AC', 'Norte', 'NORTE'), ('AM', 'Norte', 'NORTE'), ('AP', 'Norte', 'NORTE'), ('PA', 'Norte', 'NORTE'),
    ('RO', 'Norte', 'NORTE'), ('RR', 'Norte', 'NORTE'), ('TO', 'Norte', 'NORTE'),
    ('AL', 'Nordeste', 'NORDESTE'), ('BA', 'Nordeste', 'NORDESTE'), ('CE', 'Nordeste', 'NORDESTE'),
    ('MA', 'Nordeste', 'NORDESTE'), ('PB', 'Nordeste', 'NORDESTE'), ('PE', 'Nordeste', 'NORDESTE'),
    ('PI', 'Nordeste', 'NORDESTE'), ('RN', 'Nordeste', 'NORDESTE'), ('SE', 'Nordeste', 'NORDESTE'),
    ('DF', 'Centro-Oeste', 'CENTRO_OESTE'), ('GO', 'Centro-Oeste', 'CENTRO_OESTE'),
    ('MS', 'Centro-Oeste', 'CENTRO_OESTE'), ('MT', 'Centro-Oeste', 'CENTRO_OESTE'),
    ('ES', 'Sudeste', 'SUDESTE'), ('MG', 'Sudeste', 'SUDESTE'), ('RJ', 'Sudeste', 'SUDESTE'), ('SP', 'Sudeste', 'SUDESTE'),
    ('PR', 'Sul', 'SUL'), ('RS', 'Sul', 'SUL'), ('SC', 'Sul', 'SUL')
) s
ON t.state_code = s.state_code
WHEN MATCHED AND (t.region_name <> s.region_name OR t.market_code <> s.market_code)
  THEN UPDATE SET region_name = s.region_name, market_code = s.market_code
WHEN NOT MATCHED
  THEN INSERT (state_code, region_name, market_code) VALUES (s.state_code, s.region_name, s.market_code);