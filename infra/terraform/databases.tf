# ECOM_DB and its medallion/audit/governance schemas, imported as-is.
# PUBLIC is deliberately not managed.

resource "snowflake_database" "ecom_db" {
  name    = "ECOM_DB"
  comment = "Slussen governed commerce platform: medallion layers and audit"
}

resource "snowflake_schema" "audit" {
  database            = snowflake_database.ecom_db.name
  name                = "AUDIT"
  with_managed_access = "true"
  is_transient        = "false" # must be explicit: "default" forces replacement
  comment             = "Load log, contract violations, data quality results, freshness"
}

resource "snowflake_schema" "bronze" {
  database            = snowflake_database.ecom_db.name
  name                = "BRONZE"
  with_managed_access = "true"
  is_transient        = "false" # must be explicit: "default" forces replacement
  comment             = "Exact copies of validated source files, append-only, with load metadata"
}

resource "snowflake_schema" "silver" {
  database            = snowflake_database.ecom_db.name
  name                = "SILVER"
  with_managed_access = "true"
  is_transient        = "false" # must be explicit: "default" forces replacement
  comment             = "One clean table per entity: typed, deduplicated, historical and live merged"
}

resource "snowflake_schema" "gold" {
  database            = snowflake_database.ecom_db.name
  name                = "GOLD"
  with_managed_access = "true"
  is_transient        = "false" # must be explicit: "default" forces replacement
  comment             = "Star schema and dashboard marts; the only layer BI and AI tools read"
}

resource "snowflake_schema" "governance" {
  database            = snowflake_database.ecom_db.name
  name                = "GOVERNANCE"
  with_managed_access = "true"
  is_transient        = "false" # must be explicit: "default" forces replacement
  comment             = "Policies, tags and the market access mapping table"
}
