@echo off
set AWS_PROFILE=slussen-admin
set ROLE=slussen-snowflake-integration
set SF_USER_ARN=%~1
set SF_EXTERNAL_ID=%~2

if "%SF_EXTERNAL_ID%"=="" (
  echo Usage: 04_snowflake_trust.cmd "STORAGE_AWS_IAM_USER_ARN" "STORAGE_AWS_EXTERNAL_ID"
  exit /b 1
)

echo {"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"AWS":"%SF_USER_ARN%"},"Action":"sts:AssumeRole","Condition":{"StringEquals":{"sts:ExternalId":"%SF_EXTERNAL_ID%"}}}]} > %TEMP%\slussen_trust.json

aws iam update-assume-role-policy --role-name %ROLE% --policy-document file://%TEMP%\slussen_trust.json

aws iam get-role --role-name %ROLE% --query Role.AssumeRolePolicyDocument --output json