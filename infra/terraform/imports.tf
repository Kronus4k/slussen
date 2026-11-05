# One-time adoption of existing objects. Safe to keep: once in state, import
# blocks are no-ops. Session 1 expected "11 to import, 0 to add,
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

# ---------------------------------------------------------------------------
# Session 2: storage integration, IAM and S3. Expect
# "9 to import, 0 to add, 0 to change, 0 to destroy" on first adoption.

# Storage integration (owned by SYSADMIN)
import {
  to = snowflake_storage_integration.slussen_s3_int
  id = "\"SLUSSEN_S3_INT\""
}

# IAM role and its inline policy (no attached managed policies)
import {
  to = aws_iam_role.snowflake_integration
  id = "slussen-snowflake-integration"
}

import {
  to = aws_iam_role_policy.snowflake_read
  id = "slussen-snowflake-integration:slussen-snowflake-read"
}

# Lake bucket
import {
  to = aws_s3_bucket.lake
  id = "slussen-lake-qwer"
}

import {
  to = aws_s3_bucket_versioning.lake
  id = "slussen-lake-qwer"
}

import {
  to = aws_s3_bucket_public_access_block.lake
  id = "slussen-lake-qwer"
}

# State bucket (name from var.state_bucket_name, never committed)
import {
  to = aws_s3_bucket.tf_state
  id = var.state_bucket_name
}

import {
  to = aws_s3_bucket_versioning.tf_state
  id = var.state_bucket_name
}

import {
  to = aws_s3_bucket_public_access_block.tf_state
  id = var.state_bucket_name
}
