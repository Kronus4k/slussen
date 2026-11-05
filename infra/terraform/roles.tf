# Account roles, the role hierarchy between them, and their privilege grants on
# the platform objects managed in this configuration. Imported as-is from
# inventory/snowflake_grants_2026-11-05.csv (ACCOUNT_USAGE.GRANTS_TO_ROLES,
# trimmed to the in-scope rows). See README "Roles and grants" for scope.
#
# Every grant here has with_grant_option = false and always_apply = false.
# Never revoke or add a grant to make a plan clean: if a grant diffs, the
# config is wrong, not the account.

locals {
  # role name => comment (exact live value; null where the role has none)
  account_roles = {
    ANALYST_CENTRO_OESTE = null
    ANALYST_NORDESTE     = null
    ANALYST_NORTE        = null
    ANALYST_SUDESTE      = null
    ANALYST_SUL          = null
    AUDIT_READ           = null
    AUDIT_RW             = null
    BRONZE_READ          = null
    BRONZE_RW            = null
    DATA_ENGINEER        = null
    EXEC                 = null
    GOLD_READ            = null
    GOLD_RW              = null
    LOADER_ROLE          = null
    ORCHESTRATOR_ROLE    = "Airflow: reads Bronze, writes Audit results"
    PLATFORM_ADMIN       = null
    PRODUCT_OWNER        = null
    REPORTING_ROLE       = null
    SILVER_READ          = null
    SILVER_RW            = null
    TASK_EXECUTE         = null
    TRANSFORM_ROLE       = null
    WH_BI_USAGE          = null
    WH_LOAD_USAGE        = null
    WH_TRANSFORM_USAGE   = null
  }
  role_grants = {
    for pair in flatten([
      for parent, children in local.role_hierarchy : [
        for child in children : { parent = parent, role = child }
      ]
    ]) : "${pair.parent}/${pair.role}" => pair
  }

  # One resource per (role, object); privileges grouped. object is
  # DATABASE/WAREHOUSE/INTEGRATION name, "DB.SCHEMA" for SCHEMA, null for ACCOUNT.
  role_hierarchy = {
    ANALYST_CENTRO_OESTE = ["GOLD_READ", "WH_BI_USAGE"]
    ANALYST_NORDESTE     = ["GOLD_READ", "WH_BI_USAGE"]
    ANALYST_NORTE        = ["GOLD_READ", "WH_BI_USAGE"]
    ANALYST_SUDESTE      = ["GOLD_READ", "WH_BI_USAGE"]
    ANALYST_SUL          = ["GOLD_READ", "WH_BI_USAGE"]
    AUDIT_RW             = ["AUDIT_READ"]
    BRONZE_RW            = ["BRONZE_READ"]
    DATA_ENGINEER        = ["AUDIT_RW", "BRONZE_RW", "GOLD_RW", "SILVER_RW", "TASK_EXECUTE", "WH_BI_USAGE", "WH_LOAD_USAGE", "WH_TRANSFORM_USAGE"]
    EXEC                 = ["WH_BI_USAGE"]
    GOLD_RW              = ["GOLD_READ"]
    LOADER_ROLE          = ["AUDIT_RW", "BRONZE_RW", "WH_LOAD_USAGE"]
    ORCHESTRATOR_ROLE    = ["AUDIT_RW", "BRONZE_READ", "GOLD_READ", "SILVER_READ", "WH_TRANSFORM_USAGE"]
    PRODUCT_OWNER        = ["AUDIT_READ", "GOLD_READ", "WH_BI_USAGE"]
    REPORTING_ROLE       = ["AUDIT_READ", "GOLD_READ", "WH_BI_USAGE"]
    SILVER_RW            = ["SILVER_READ"]
    TRANSFORM_ROLE       = ["AUDIT_RW", "BRONZE_READ", "GOLD_RW", "SILVER_RW", "WH_TRANSFORM_USAGE"]
  }

  privilege_grants = {
    "AUDIT_READ/DATABASE/ECOM_DB"               = { role = "AUDIT_READ", on = "DATABASE", object = "ECOM_DB", privileges = ["USAGE"], with_grant_option = false }
    "AUDIT_READ/SCHEMA/ECOM_DB.AUDIT"           = { role = "AUDIT_READ", on = "SCHEMA", object = "ECOM_DB.AUDIT", privileges = ["USAGE"], with_grant_option = false }
    "AUDIT_RW/SCHEMA/ECOM_DB.AUDIT"             = { role = "AUDIT_RW", on = "SCHEMA", object = "ECOM_DB.AUDIT", privileges = ["CREATE FILE FORMAT", "CREATE PIPE", "CREATE PROCEDURE", "CREATE STAGE", "CREATE TABLE", "CREATE TASK", "CREATE VIEW"], with_grant_option = false }
    "BRONZE_READ/DATABASE/ECOM_DB"              = { role = "BRONZE_READ", on = "DATABASE", object = "ECOM_DB", privileges = ["USAGE"], with_grant_option = false }
    "BRONZE_READ/SCHEMA/ECOM_DB.BRONZE"         = { role = "BRONZE_READ", on = "SCHEMA", object = "ECOM_DB.BRONZE", privileges = ["USAGE"], with_grant_option = false }
    "BRONZE_RW/SCHEMA/ECOM_DB.BRONZE"           = { role = "BRONZE_RW", on = "SCHEMA", object = "ECOM_DB.BRONZE", privileges = ["CREATE FILE FORMAT", "CREATE PIPE", "CREATE STAGE", "CREATE TABLE", "CREATE VIEW"], with_grant_option = false }
    "DATA_ENGINEER/INTEGRATION/SLUSSEN_S3_INT"  = { role = "DATA_ENGINEER", on = "INTEGRATION", object = "SLUSSEN_S3_INT", privileges = ["USAGE"], with_grant_option = false }
    "GOLD_READ/DATABASE/ECOM_DB"                = { role = "GOLD_READ", on = "DATABASE", object = "ECOM_DB", privileges = ["USAGE"], with_grant_option = false }
    "GOLD_READ/SCHEMA/ECOM_DB.GOLD"             = { role = "GOLD_READ", on = "SCHEMA", object = "ECOM_DB.GOLD", privileges = ["USAGE"], with_grant_option = false }
    "GOLD_RW/SCHEMA/ECOM_DB.GOLD"               = { role = "GOLD_RW", on = "SCHEMA", object = "ECOM_DB.GOLD", privileges = ["CREATE DYNAMIC TABLE", "CREATE SEMANTIC VIEW", "CREATE TABLE", "CREATE VIEW"], with_grant_option = false }
    "LOADER_ROLE/INTEGRATION/SLUSSEN_S3_INT"    = { role = "LOADER_ROLE", on = "INTEGRATION", object = "SLUSSEN_S3_INT", privileges = ["USAGE"], with_grant_option = false }
    "SILVER_READ/DATABASE/ECOM_DB"              = { role = "SILVER_READ", on = "DATABASE", object = "ECOM_DB", privileges = ["USAGE"], with_grant_option = false }
    "SILVER_READ/SCHEMA/ECOM_DB.SILVER"         = { role = "SILVER_READ", on = "SCHEMA", object = "ECOM_DB.SILVER", privileges = ["USAGE"], with_grant_option = false }
    "SILVER_RW/SCHEMA/ECOM_DB.SILVER"           = { role = "SILVER_RW", on = "SCHEMA", object = "ECOM_DB.SILVER", privileges = ["CREATE DYNAMIC TABLE", "CREATE FUNCTION", "CREATE PROCEDURE", "CREATE STREAM", "CREATE TABLE", "CREATE TASK", "CREATE VIEW"], with_grant_option = false }
    "TASK_EXECUTE/ACCOUNT"                      = { role = "TASK_EXECUTE", on = "ACCOUNT", object = null, privileges = ["EXECUTE MANAGED TASK", "EXECUTE TASK"], with_grant_option = false }
    "WH_BI_USAGE/WAREHOUSE/BI_WH"               = { role = "WH_BI_USAGE", on = "WAREHOUSE", object = "BI_WH", privileges = ["MONITOR", "OPERATE", "USAGE"], with_grant_option = false }
    "WH_LOAD_USAGE/WAREHOUSE/LOAD_WH"           = { role = "WH_LOAD_USAGE", on = "WAREHOUSE", object = "LOAD_WH", privileges = ["MONITOR", "OPERATE", "USAGE"], with_grant_option = false }
    "WH_TRANSFORM_USAGE/WAREHOUSE/TRANSFORM_WH" = { role = "WH_TRANSFORM_USAGE", on = "WAREHOUSE", object = "TRANSFORM_WH", privileges = ["MONITOR", "OPERATE", "USAGE"], with_grant_option = false }
  }

  account_object_types = ["DATABASE", "WAREHOUSE", "INTEGRATION"]

  # Provider import IDs: "<role>"|<with_grant_option>|<always_apply>|<privileges>|<target>
  privilege_grant_import_ids = {
    for k, g in local.privilege_grants : k => join("|", concat(
      ["\"${g.role}\"", tostring(g.with_grant_option), "false", join(",", g.privileges)],
      g.on == "ACCOUNT" ? ["OnAccount"] : (
        g.on == "SCHEMA"
        ? ["OnSchema", "OnSchema", join(".", [for p in split(".", g.object) : "\"${p}\""])]
        : ["OnAccountObject", g.on, "\"${g.object}\""]
      )
    ))
  }
}

resource "snowflake_account_role" "this" {
  for_each = local.account_roles

  name    = each.key
  comment = each.value
}

resource "snowflake_grant_account_role" "this" {
  for_each = local.role_grants

  role_name        = snowflake_account_role.this[each.value.role].name
  parent_role_name = snowflake_account_role.this[each.value.parent].name
}

resource "snowflake_grant_privileges_to_account_role" "this" {
  for_each = local.privilege_grants

  account_role_name = snowflake_account_role.this[each.value.role].name
  privileges        = each.value.privileges
  with_grant_option = each.value.with_grant_option

  on_account = each.value.on == "ACCOUNT" ? true : null

  dynamic "on_account_object" {
    for_each = contains(local.account_object_types, each.value.on) ? [each.value] : []
    content {
      object_type = on_account_object.value.on
      object_name = on_account_object.value.object
    }
  }

  dynamic "on_schema" {
    for_each = each.value.on == "SCHEMA" ? [each.value] : []
    content {
      schema_name = join(".", [for p in split(".", on_schema.value.object) : "\"${p}\""])
    }
  }
}

# ---------------------------------------------------------------------------
# Session 3 adoption. Expect "85 to import, 0 to add, 0 to change,
# 0 to destroy" (25 roles, 42 role grants, 18 privilege grants).

import {
  for_each = local.account_roles
  to       = snowflake_account_role.this[each.key]
  id       = "\"${each.key}\""
}

import {
  for_each = local.role_grants
  to       = snowflake_grant_account_role.this[each.key]
  id       = "\"${each.value.role}\"|ROLE|\"${each.value.parent}\""
}

import {
  for_each = local.privilege_grant_import_ids
  to       = snowflake_grant_privileges_to_account_role.this[each.key]
  id       = each.value
}
