# Existing warehouses, imported as-is (see imports.tf). Values mirror
# inventory/snowflake_inventory_2026-11-05.csv.
#
# resource_monitor: every warehouse is currently unassigned (null); the
# SLUSSEN_MONITOR is attached at ACCOUNT level instead. Only ACCOUNTADMIN can
# change warehouse monitor assignments, so it is left unset and ignored.
#
# statement_timeout_in_seconds is set at object level on BI_WH (600) and
# LOAD_WH/TRANSFORM_WH (1800); COMPUTE_WH inherits the account default.
# These are not in the SHOW WAREHOUSES inventory but are read back on import.
#
# warehouse_type/generation/cluster counts/scaling_policy equal Snowflake's
# defaults but are pinned explicitly; leaving them out makes the provider plan
# an ALTER ... UNSET.
#
# initially_suspended only applies at CREATE time; these warehouses already
# exist, so it is ignored to avoid a spurious diff.

resource "snowflake_warehouse" "bi_wh" {
  name                                = "BI_WH"
  warehouse_type                      = "STANDARD"
  warehouse_size                      = "XSMALL"
  generation                          = "1"
  min_cluster_count                   = 1
  max_cluster_count                   = 1
  scaling_policy                      = "STANDARD"
  auto_suspend                        = 60
  auto_resume                         = "true"
  enable_query_acceleration           = "true"
  query_acceleration_max_scale_factor = 8
  statement_timeout_in_seconds        = 600
  comment                             = "Reporting: Power BI refreshes, Cortex Analyst queries"

  lifecycle {
    ignore_changes = [resource_monitor, initially_suspended]
  }
}

resource "snowflake_warehouse" "compute_wh" {
  name                                = "COMPUTE_WH"
  warehouse_type                      = "STANDARD"
  warehouse_size                      = "XSMALL"
  generation                          = "1"
  min_cluster_count                   = 1
  max_cluster_count                   = 1
  scaling_policy                      = "STANDARD"
  auto_suspend                        = 60
  auto_resume                         = "true"
  enable_query_acceleration           = "true"
  query_acceleration_max_scale_factor = 8

  lifecycle {
    ignore_changes = [resource_monitor, initially_suspended]
  }
}

resource "snowflake_warehouse" "load_wh" {
  name                                = "LOAD_WH"
  warehouse_type                      = "STANDARD"
  warehouse_size                      = "XSMALL"
  generation                          = "1"
  min_cluster_count                   = 1
  max_cluster_count                   = 1
  scaling_policy                      = "STANDARD"
  auto_suspend                        = 60
  auto_resume                         = "true"
  enable_query_acceleration           = "true"
  query_acceleration_max_scale_factor = 8
  statement_timeout_in_seconds        = 1800
  comment                             = "Loading: COPY INTO, Snowpipe-related work"

  lifecycle {
    ignore_changes = [resource_monitor, initially_suspended]
  }
}

resource "snowflake_warehouse" "transform_wh" {
  name                                = "TRANSFORM_WH"
  warehouse_type                      = "STANDARD"
  warehouse_size                      = "XSMALL"
  generation                          = "1"
  min_cluster_count                   = 1
  max_cluster_count                   = 1
  scaling_policy                      = "STANDARD"
  auto_suspend                        = 60
  auto_resume                         = "true"
  enable_query_acceleration           = "true"
  query_acceleration_max_scale_factor = 8
  statement_timeout_in_seconds        = 1800
  comment                             = "Transforms: Dynamic Tables, tasks, MERGE"

  lifecycle {
    ignore_changes = [resource_monitor, initially_suspended]
  }
}
