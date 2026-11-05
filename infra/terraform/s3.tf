# The lake bucket and the Terraform state bucket: bucket, versioning and
# public access block only.
#
# Deliberately NOT managed: bucket policies, event notifications (EventBridge
# -> contract gate / Snowpipe), lifecycle rules and default encryption (KMS).
# Adding any of those resources would let Terraform overwrite live wiring.
#
# Tags (project = slussen on the lake bucket) are out of scope and ignored.

resource "aws_s3_bucket" "lake" {
  bucket = local.lake_bucket_name

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [tags, tags_all]
  }
}

resource "aws_s3_bucket_versioning" "lake" {
  bucket = aws_s3_bucket.lake.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "lake" {
  bucket                  = aws_s3_bucket.lake.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "tf_state" {
  bucket = var.state_bucket_name

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [tags, tags_all]
  }
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket                  = aws_s3_bucket.tf_state.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}
