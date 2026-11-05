terraform {
  required_version = "1.11.4"

  required_providers {
    snowflake = {
      source  = "snowflakedb/snowflake"
      version = "2.22.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "6.69.1"
    }
  }
}
