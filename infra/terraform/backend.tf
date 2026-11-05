# Remote state in S3 with native S3 locking (no DynamoDB table).
# The bucket name is intentionally NOT committed. Supply it at init time:
#   terraform init -backend-config="bucket=$TF_STATE_BUCKET"
terraform {
  backend "s3" {
    key          = "slussen/terraform.tfstate"
    region       = "eu-north-1"
    use_lockfile = true
    encrypt      = true
  }
}
