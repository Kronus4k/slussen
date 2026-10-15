USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS ECOM_DB
  COMMENT = 'Slussen governed commerce platform: medallion layers and audit';

CREATE SCHEMA IF NOT EXISTS ECOM_DB.BRONZE WITH MANAGED ACCESS
  COMMENT = 'Exact copies of validated source files, append-only, with load metadata';

CREATE SCHEMA IF NOT EXISTS ECOM_DB.SILVER WITH MANAGED ACCESS
  COMMENT = 'One clean table per entity: typed, deduplicated, historical and live merged';

CREATE SCHEMA IF NOT EXISTS ECOM_DB.GOLD WITH MANAGED ACCESS
  COMMENT = 'Star schema and dashboard marts; the only layer BI and AI tools read';

CREATE SCHEMA IF NOT EXISTS ECOM_DB.AUDIT WITH MANAGED ACCESS
  COMMENT = 'Load log, contract violations, data quality results, freshness';

CREATE SCHEMA IF NOT EXISTS ECOM_DB.GOVERNANCE WITH MANAGED ACCESS
  COMMENT = 'Policies, tags and the market access mapping table';

SHOW SCHEMAS IN DATABASE ECOM_DB;