# Snowflake provider.
# Everything except the private key comes from environment variables, so no
# account identifiers live in this repository:
#   SNOWFLAKE_ORGANIZATION_NAME, SNOWFLAKE_ACCOUNT_NAME, SNOWFLAKE_USER,
#   SNOWFLAKE_ROLE, SNOWFLAKE_AUTHENTICATOR (SNOWFLAKE_JWT),
#   SNOWFLAKE_PRIVATE_KEY_PASSPHRASE
# The encrypted .p8 key is read from a path outside the repo
# (TF_VAR_snowflake_private_key_path).
provider "snowflake" {
  private_key = file(var.snowflake_private_key_path)

  # Required by snowflake_storage_integration (see storage_integration.tf).
  preview_features_enabled = ["snowflake_storage_integration_resource"]
}

# AWS provider.
# Credentials come from AWS_PROFILE (SSO); no profile name or account ID is
# committed. Account-specific ARNs are built from data.aws_caller_identity.
provider "aws" {
  region = "eu-north-1"
}

data "aws_caller_identity" "current" {}
