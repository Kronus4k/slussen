variable "snowflake_private_key_path" {
  description = "Absolute path to the encrypted PKCS#8 (.p8) private key for TERRAFORM_SVC. Must live outside the repository. Usually set via TF_VAR_snowflake_private_key_path."
  type        = string
}

variable "state_bucket_name" {
  description = "Name of the S3 bucket that holds this configuration's remote state. Not committed; set via TF_VAR_state_bucket_name (same value as TF_STATE_BUCKET)."
  type        = string
}
