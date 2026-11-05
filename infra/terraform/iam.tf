# IAM role assumed by SLUSSEN_S3_INT, and its single inline policy (no managed
# policies are attached). Imported as-is.
#
# The trust policy is built from the storage integration's DESC INTEGRATION
# read-back (describe_output), so it always matches what Snowflake presents
# and neither the external ID nor Snowflake's AWS account ID is committed.
# See README "Storage integration and the IAM trust policy".
#
# Tags (project = slussen) are set on the live role but are out of scope here;
# they are ignored, not managed.

locals {
  # Read from DESC INTEGRATION (describe_output). The top-level
  # storage_aws_external_id is an optional input that the provider does not
  # read back on import, so it would be null here.
  integration_desc         = snowflake_storage_integration.slussen_s3_int.describe_output[0]
  integration_iam_user_arn = local.integration_desc.storage_aws_iam_user_arn[0].value
  integration_external_id  = local.integration_desc.storage_aws_external_id[0].value

  lake_bucket_name                = "slussen-lake-qwer"
  snowflake_integration_role_name = "slussen-snowflake-integration"

  # KMS key that encrypts the lake. The key itself is not managed here.
  lake_kms_key_id = "098fa594-1cf7-4c09-9fb4-21f3557328db"
  lake_kms_key_arn = format(
    "arn:aws:kms:%s:%s:key/%s",
    data.aws_region.current.region,
    data.aws_caller_identity.current.account_id,
    local.lake_kms_key_id,
  )
}

resource "aws_iam_role" "snowflake_integration" {
  name                 = local.snowflake_integration_role_name
  path                 = "/"
  description          = "Assumed by Snowflake storage integration to read the Slussen lake"
  max_session_duration = 3600

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = local.integration_iam_user_arn
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = local.integration_external_id
          }
        }
      }
    ]
  })

  lifecycle {
    ignore_changes = [tags, tags_all]
  }
}

resource "aws_iam_role_policy" "snowflake_read" {
  name = "slussen-snowflake-read"
  role = aws_iam_role.snowflake_integration.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadObjects"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:GetObjectVersion"]
        Resource = [
          "arn:aws:s3:::${local.lake_bucket_name}/validated/*",
          "arn:aws:s3:::${local.lake_bucket_name}/audit/contract_violations/*",
        ]
      },
      {
        Sid      = "ListPrefixes"
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = "arn:aws:s3:::${local.lake_bucket_name}"
        Condition = {
          StringLike = {
            "s3:prefix" = ["validated/*", "audit/contract_violations/*"]
          }
        }
      },
      {
        Sid      = "BucketLocation"
        Effect   = "Allow"
        Action   = "s3:GetBucketLocation"
        Resource = "arn:aws:s3:::${local.lake_bucket_name}"
      },
      {
        Sid      = "DecryptWithLakeKey"
        Effect   = "Allow"
        Action   = "kms:Decrypt"
        Resource = local.lake_kms_key_arn
      },
    ]
  })
}
