@echo off
setlocal
set PROFILE=slussen-admin
set REGION=eu-north-1
set ROLE=slussen-snowflake-integration
set POLICY_NAME=slussen-snowflake-read
set BUCKET=slussen-lake-qwer
set RENDERED=%TEMP%\slussen_snowflake_policy.json

for /f %%a in ('aws kms describe-key --key-id alias/slussen-data --profile %PROFILE% --region %REGION% --query KeyMetadata.Arn --output text') do set KMS_ARN=%%a
if "%KMS_ARN%"=="" exit /b 1

powershell -NoProfile -Command "(Get-Content -Raw 'infra\iam\snowflake_integration_policy.json').Replace('__BUCKET__','%BUCKET%').Replace('__KMS_KEY_ARN__','%KMS_ARN%') | Set-Content -NoNewline -Encoding ascii '%RENDERED%'"

aws iam put-role-policy --role-name %ROLE% --policy-name %POLICY_NAME% --policy-document "file://%RENDERED%" --profile %PROFILE%
set RESULT=%errorlevel%
del "%RENDERED%"
if not "%RESULT%"=="0" exit /b 1
echo Policy %POLICY_NAME% replaced on %ROLE%
endlocal