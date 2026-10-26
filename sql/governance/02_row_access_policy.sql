-- Row access policy RAP_MARKET: a Gold row is visible when a role in the session is mapped
-- to the row's market, or to ALL, in GOVERNANCE.MARKET_ACCESS.
-- Attached to the Gold objects by the next file (03_apply_row_access.sql).
-- Runs as: PLATFORM_ADMIN (owns GOVERNANCE). Run with Run All; the file is DDL only.
-- Rerun: safe. An attached policy can't be replaced, so the policy is created once
--   (IF NOT EXISTS) and its body is always set with ALTER ... SET BODY.
USE ROLE PLATFORM_ADMIN;

-- Placeholder body FALSE: if the ALTER below never ran, the policy hides every row (fails closed).
-- The argument is named row_market, not market_code: inside the body an argument with the same
-- name as a mapping-table column resolves to the column, and the filter would compare
-- m.market_code with itself.
CREATE ROW ACCESS POLICY IF NOT EXISTS ECOM_DB.GOVERNANCE.RAP_MARKET
  AS (row_market VARCHAR) RETURNS BOOLEAN -> FALSE;

-- IS_ROLE_IN_SESSION, not CURRENT_ROLE: it follows the role hierarchy and secondary roles,
-- so a role that inherits a mapped role sees the same markets.
-- A role with no mapping row sees nothing.
ALTER ROW ACCESS POLICY ECOM_DB.GOVERNANCE.RAP_MARKET SET BODY ->
  EXISTS (
    SELECT 1
    FROM ECOM_DB.GOVERNANCE.MARKET_ACCESS m
    WHERE IS_ROLE_IN_SESSION(m.role_name)
      AND (m.market_code = 'ALL' OR m.market_code = row_market)
  );

USE ROLE DATA_ENGINEER;