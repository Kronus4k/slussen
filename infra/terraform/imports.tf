# One-time adoption of existing objects. Safe to keep: once in state, import
# blocks are no-ops. Run `terraform plan` and expect "11 to import, 0 to add,
# 0 to change, 0 to destroy".

# Warehouses
import {
  to = snowflake_warehouse.bi_wh
  id = "\"BI_WH\""
}

import {
  to = snowflake_warehouse.compute_wh
  id = "\"COMPUTE_WH\""
}

import {
  to = snowflake_warehouse.load_wh
  id = "\"LOAD_WH\""
}

import {
  to = snowflake_warehouse.transform_wh
  id = "\"TRANSFORM_WH\""
}

# Database and schemas
import {
  to = snowflake_database.ecom_db
  id = "\"ECOM_DB\""
}

import {
  to = snowflake_schema.audit
  id = "\"ECOM_DB\".\"AUDIT\""
}

import {
  to = snowflake_schema.bronze
  id = "\"ECOM_DB\".\"BRONZE\""
}

import {
  to = snowflake_schema.silver
  id = "\"ECOM_DB\".\"SILVER\""
}

import {
  to = snowflake_schema.gold
  id = "\"ECOM_DB\".\"GOLD\""
}

import {
  to = snowflake_schema.governance
  id = "\"ECOM_DB\".\"GOVERNANCE\""
}

# Resource monitor
import {
  to = snowflake_resource_monitor.slussen_monitor
  id = "\"SLUSSEN_MONITOR\""
}
