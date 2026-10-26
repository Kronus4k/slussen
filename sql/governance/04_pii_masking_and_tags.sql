-- Tags and PII masking for Gold: the PII and DOMAIN tags, the masking policy MASK_PII_STRING,
-- the tags on the Gold objects, and the binding of the masking policy to the PII tag.
-- Runs as: PLATFORM_ADMIN (owns GOVERNANCE, holds APPLY TAG and APPLY MASKING POLICY
--   on the account). Run with Run All; the file is DDL only.
-- Rerun: required after any Gold object is re-created (CREATE OR REPLACE drops its tags).
--   On a rerun the last ALTER TAG fails because the tag already has the policy; that error is
--   expected, everything before it has run, and the binding itself is kept.
USE ROLE PLATFORM_ADMIN;

-- ALLOWED_VALUES rejects typos in tag values.
CREATE TAG IF NOT EXISTS ECOM_DB.GOVERNANCE.PII ALLOWED_VALUES 'location' COMMENT = 'Personal data class of a column';
CREATE TAG IF NOT EXISTS ECOM_DB.GOVERNANCE.DOMAIN ALLOWED_VALUES 'commercial' COMMENT = 'Business domain of a Gold object';

-- Same pattern as the row access policy: a policy in use can't be replaced, so it is
-- created once and its body is always set with ALTER ... SET BODY.
-- IS_ROLE_IN_SESSION also counts secondary roles, so PII_READER can be added on top of
-- an analyst role. Every other role, DATA_ENGINEER included, sees the masked value.
CREATE MASKING POLICY IF NOT EXISTS ECOM_DB.GOVERNANCE.MASK_PII_STRING AS (val VARCHAR) RETURNS VARCHAR -> '***MASKED***';
ALTER MASKING POLICY ECOM_DB.GOVERNANCE.MASK_PII_STRING SET BODY ->
  CASE WHEN IS_ROLE_IN_SESSION('PII_READER') THEN val ELSE '***MASKED***' END;

-- Customer location columns are personal data.
ALTER DYNAMIC TABLE ECOM_DB.GOLD.DIM_CUSTOMER MODIFY COLUMN customer_zip_code_prefix SET TAG ECOM_DB.GOVERNANCE.PII = 'location';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.DIM_CUSTOMER MODIFY COLUMN customer_city SET TAG ECOM_DB.GOVERNANCE.PII = 'location';

-- Every Gold object belongs to the commercial domain (catalog search and AI tools use it).
ALTER DYNAMIC TABLE ECOM_DB.GOLD.FCT_ORDERS SET TAG ECOM_DB.GOVERNANCE.DOMAIN = 'commercial';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.FCT_ORDER_ITEMS SET TAG ECOM_DB.GOVERNANCE.DOMAIN = 'commercial';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.DIM_CUSTOMER SET TAG ECOM_DB.GOVERNANCE.DOMAIN = 'commercial';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.DIM_PRODUCT SET TAG ECOM_DB.GOVERNANCE.DOMAIN = 'commercial';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.MART_DAILY_REVENUE SET TAG ECOM_DB.GOVERNANCE.DOMAIN = 'commercial';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.MART_CATEGORY_MONTHLY SET TAG ECOM_DB.GOVERNANCE.DOMAIN = 'commercial';
ALTER DYNAMIC TABLE ECOM_DB.GOLD.MART_COHORT_RETENTION SET TAG ECOM_DB.GOVERNANCE.DOMAIN = 'commercial';
ALTER VIEW ECOM_DB.GOLD.DIM_DATE SET TAG ECOM_DB.GOVERNANCE.DOMAIN = 'commercial';
ALTER VIEW ECOM_DB.GOLD.DIM_MARKET SET TAG ECOM_DB.GOVERNANCE.DOMAIN = 'commercial';

-- Tag-based masking: binding the policy to the tag masks every column that carries the tag,
-- including columns tagged later, without attaching a policy per column.
ALTER TAG ECOM_DB.GOVERNANCE.PII SET MASKING POLICY ECOM_DB.GOVERNANCE.MASK_PII_STRING;

USE ROLE DATA_ENGINEER;