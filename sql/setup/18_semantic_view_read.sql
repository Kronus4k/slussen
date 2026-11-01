-- Read access to semantic views in ECOM_DB.GOLD for every role that reads Gold.
--
-- Grain: two future grants on the GOLD schema, held by the access role GOLD_READ.
-- Runs as: SECURITYADMIN. GOLD is a managed-access schema owned by SYSADMIN, so only
--          the schema owner or a role with MANAGE GRANTS can grant on objects inside it.
-- Safe to rerun: yes, grants are idempotent.
--
-- Semantic views are their own object type: the existing future grants on tables and
-- dynamic tables don't cover them. Cortex Analyst needs SELECT on the semantic view and
-- on its underlying tables; the tables are already covered by GOLD_READ, and the row
-- access policy on them still filters by market for the querying role.
-- REFERENCES lets a role see the definition (DESCRIBE) without querying it.
-- Future grants apply only to objects created after this runs.

USE ROLE SECURITYADMIN;

GRANT SELECT ON FUTURE SEMANTIC VIEWS IN SCHEMA ECOM_DB.GOLD TO ROLE GOLD_READ;
GRANT REFERENCES ON FUTURE SEMANTIC VIEWS IN SCHEMA ECOM_DB.GOLD TO ROLE GOLD_READ;

SHOW FUTURE GRANTS IN SCHEMA ECOM_DB.GOLD;