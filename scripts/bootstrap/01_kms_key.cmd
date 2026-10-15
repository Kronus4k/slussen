@echo off
set AWS_PROFILE=slussen-admin
set AWS_REGION=eu-north-1

for /f %%i in ('aws kms create-key --description "Slussen data lake encryption key" --tags TagKey^=project^,TagValue^=slussen --query KeyMetadata.KeyId --output text') do set KEY_ID=%%i
aws kms create-alias --alias-name alias/slussen-data --target-key-id %KEY_ID%
aws kms enable-key-rotation --key-id %KEY_ID%
aws kms describe-key --key-id alias/slussen-data --query "KeyMetadata.[KeyState,Arn]" --output table