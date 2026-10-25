USE ROLE PLATFORM_ADMIN;
USE WAREHOUSE TRANSFORM_WH;

CREATE TABLE IF NOT EXISTS ECOM_DB.GOVERNANCE.MARKET_ACCESS (
  role_name VARCHAR NOT NULL,
  market_code VARCHAR NOT NULL,
  note VARCHAR,
  CONSTRAINT pk_market_access PRIMARY KEY (role_name, market_code)
);

MERGE INTO ECOM_DB.GOVERNANCE.MARKET_ACCESS t
USING (
  SELECT column1 AS role_name, column2 AS market_code, column3 AS note
  FROM VALUES
    ('DATA_ENGINEER', 'ALL', 'dynamic table owner, must see all rows'),
    ('EXEC', 'ALL', 'executive persona'),
    ('REPORTING_ROLE', 'ALL', 'Power BI service role, Power BI RLS narrows per user'),
    ('PRODUCT_OWNER', 'SUDESTE', 'assigned market'),
    ('PRODUCT_OWNER', 'SUL', 'assigned market'),
    ('ANALYST_SUDESTE', 'SUDESTE', 'regional analyst'),
    ('ANALYST_SUL', 'SUL', 'regional analyst'),
    ('ANALYST_NORDESTE', 'NORDESTE', 'regional analyst'),
    ('ANALYST_NORTE', 'NORTE', 'regional analyst'),
    ('ANALYST_CENTRO_OESTE', 'CENTRO_OESTE', 'regional analyst')
) s
ON t.role_name = s.role_name AND t.market_code = s.market_code
WHEN MATCHED AND COALESCE(t.note, '') <> COALESCE(s.note, '') THEN UPDATE SET note = s.note
WHEN NOT MATCHED THEN INSERT (role_name, market_code, note) VALUES (s.role_name, s.market_code, s.note);

USE ROLE DATA_ENGINEER;