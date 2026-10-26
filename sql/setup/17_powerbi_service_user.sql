-- Service user for Power BI Desktop: imports Gold through REPORTING_ROLE on BI_WH.
-- Key-pair login only (TYPE = SERVICE has no password and no MFA prompt); the encrypted
-- private key and its passphrase stay on the Power BI machine, outside the repo.
-- The public key is set outside this file (see below), so no key material is versioned.
-- Runs as: USERADMIN (owns users), then SECURITYADMIN (grants). Run with Run All; DDL only.
-- Rerun: safe. CREATE ... IF NOT EXISTS keeps the user and its key; the ALTER re-applies
--   the settings; the grant is idempotent.
-- Public key: generate with scripts/bootstrap/23_powerbi_keypair.cmd, then run
--   ALTER USER SVC_POWERBI SET RSA_PUBLIC_KEY = '<key without header lines>' as USERADMIN
--   and compare DESC USER's RSA_PUBLIC_KEY_FP with the fingerprint the script prints.
USE ROLE USERADMIN;

CREATE USER IF NOT EXISTS SVC_POWERBI
  TYPE = SERVICE
  DEFAULT_ROLE = REPORTING_ROLE
  DEFAULT_WAREHOUSE = BI_WH
  COMMENT = 'Power BI Desktop import of Gold; key-pair login only';

-- New users get secondary roles ALL by default; Power BI must see exactly what
-- REPORTING_ROLE sees. UTC keeps timestamps the same as every other session.
ALTER USER SVC_POWERBI SET
  TYPE = SERVICE
  DEFAULT_ROLE = REPORTING_ROLE
  DEFAULT_WAREHOUSE = BI_WH
  DEFAULT_SECONDARY_ROLES = ()
  TIMEZONE = 'UTC';

USE ROLE SECURITYADMIN;

-- REPORTING_ROLE reads Gold (all markets in MARKET_ACCESS; Power BI RLS narrows per market).
GRANT ROLE REPORTING_ROLE TO USER SVC_POWERBI;

USE ROLE DATA_ENGINEER;