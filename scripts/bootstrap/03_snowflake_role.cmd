@echo off
set AWS_PROFILE=slussen-admin
set AWS_REGION=eu-north-1
set BUCKET=slussen-lake-qwer
set ROLE=slussen-snowflake-integration

for /f %%i in ('aws sts get-caller-identity --query Account --output text') do set ACCOUNT_ID=%%i
for /f %%i in ('aws kms describe-key --key-id alias/slussen-data --query KeyMetadata.Arn --output text') do set KEY_ARN=%%i

echo {"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"AWS":"arn:aws:iam::%ACCOUNT_ID%:root"},"Action":"sts:AssumeRole","Condition":{"StringEquals":{"sts:ExternalId":"0000"}}}]} > %TEMP%\slussen_trust.json

echo {"Version":"2012-10-17","Statement":[{"Sid":"ReadObjects","Effect":"Allow","Action":["s3:GetObject","s3:GetObjectVersion"],"Resource":["arn:aws:s3:::%BUCKET%/landing/olist/*","arn:aws:s3:::%BUCKET%/validated/*"]},{"Sid":"ListPrefixes","Effect":"Allow","Action":"s3:ListBucket","Resource":"arn:aws:s3:::%BUCKET%","Condition":{"StringLike":{"s3:prefix":["landing/olist/*","validated/*"]}}},{"Sid":"BucketLocation","Effect":"Allow","Action":"s3:GetBucketLocation","Resource":"arn:aws:s3:::%BUCKET%"},{"Sid":"DecryptWithLakeKey","Effect":"Allow","Action":"kms:Decrypt","Resource":"%KEY_ARN%"}]} > %TEMP%\slussen_snowflake_read.json

aws iam create-role --role-name %ROLE% --assume-role-policy-document file://%TEMP%\slussen_trust.json --description "Assumed by Snowflake storage integration to read the Slussen lake" --tags Key=project,Value=slussen --query Role.Arn --output text

aws iam put-role-policy --role-name %ROLE% --policy-name slussen-snowflake-read --policy-document file://%TEMP%\slussen_snowflake_read.json

aws iam list-role-policies --role-name %ROLE%