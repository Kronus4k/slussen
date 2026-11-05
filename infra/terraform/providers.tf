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
}
