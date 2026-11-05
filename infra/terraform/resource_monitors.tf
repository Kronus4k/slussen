# SLUSSEN_MONITOR: owned by ACCOUNTADMIN, attached at ACCOUNT level.
# TERRAFORM_ROLE holds MONITOR + MODIFY on it, so it can read and alter the
# quota/triggers, but the account-level assignment is outside this resource.

resource "snowflake_resource_monitor" "slussen_monitor" {
  name                      = "SLUSSEN_MONITOR"
  credit_quota              = 25
  frequency                 = "MONTHLY"
  start_timestamp           = "2026-10-14T15:42:42.053+02:00" # = 2026-10-14 13:42:42.053 UTC, as read back by the provider
  notify_triggers           = [50, 80]
  suspend_trigger           = 100
  suspend_immediate_trigger = 110
}
