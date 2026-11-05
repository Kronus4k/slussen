# SLUSSEN_S3_INT: the S3 storage integration behind STG_VALIDATED and
# STG_CONTRACT_VIOLATIONS. Owned by SYSADMIN; imported as-is.
#
# Allowed locations are the two gated prefixes only (sql/setup/11_...): the
# raw landing prefix was removed so Snowflake can read nothing the contract
# gate has not validated.
#
# snowflake_storage_integration is deprecated in provider 2.x in favour of
# snowflake_storage_integration_aws. It is used here because it exposes
# storage_aws_iam_user_arn as a top-level attribute, which the IAM trust policy
# in iam.tf is built from.

resource "snowflake_storage_integration" "slussen_s3_int" {
  name             = "SLUSSEN_S3_INT"
  type             = "EXTERNAL_STAGE"
  enabled          = true
  storage_provider = "S3"
  storage_aws_role_arn = format(
    "arn:aws:iam::%s:role/%s",
    data.aws_caller_identity.current.account_id,
    local.snowflake_integration_role_name,
  )
  storage_allowed_locations = [
    "s3://${local.lake_bucket_name}/validated/",
    "s3://${local.lake_bucket_name}/audit/contract_violations/",
  ]
  use_privatelink_endpoint = "false"
  comment                  = "Read access to the Slussen lake via IAM role slussen-snowflake-integration"
}
