variable "snowflake_private_key_path" {
  description = "Absolute path to the encrypted PKCS#8 (.p8) private key for TERRAFORM_SVC. Must live outside the repository. Usually set via TF_VAR_snowflake_private_key_path."
  type        = string
}
