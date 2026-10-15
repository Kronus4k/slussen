@echo off
set AWS_PROFILE=slussen-admin
set AWS_REGION=eu-north-1
set BUCKET=slussen-lake-qwer

for /f %%i in ('aws kms describe-key --key-id alias/slussen-data --query KeyMetadata.Arn --output text') do set KEY_ARN=%%i

aws s3api create-bucket --bucket %BUCKET% --create-bucket-configuration LocationConstraint=eu-north-1

aws s3api put-public-access-block --bucket %BUCKET% --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

aws s3api put-bucket-versioning --bucket %BUCKET% --versioning-configuration Status=Enabled

echo {"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"aws:kms","KMSMasterKeyID":"%KEY_ARN%"},"BucketKeyEnabled":true}]} > %TEMP%\slussen_enc.json
aws s3api put-bucket-encryption --bucket %BUCKET% --server-side-encryption-configuration file://%TEMP%\slussen_enc.json

echo {"Rules":[{"ID":"expire-old-versions","Status":"Enabled","Filter":{},"NoncurrentVersionExpiration":{"NoncurrentDays":30},"AbortIncompleteMultipartUpload":{"DaysAfterInitiation":7}}]} > %TEMP%\slussen_lifecycle.json
aws s3api put-bucket-lifecycle-configuration --bucket %BUCKET% --lifecycle-configuration file://%TEMP%\slussen_lifecycle.json

aws s3api put-bucket-tagging --bucket %BUCKET% --tagging "TagSet=[{Key=project,Value=slussen}]"

aws s3api get-bucket-encryption --bucket %BUCKET% --query "ServerSideEncryptionConfiguration.Rules[0].[ApplyServerSideEncryptionByDefault.SSEAlgorithm,BucketKeyEnabled]" --output table
aws s3api get-bucket-versioning --bucket %BUCKET%