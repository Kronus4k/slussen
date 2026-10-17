@echo off
setlocal
set PROFILE=slussen-admin
set REGION=eu-north-1
set ROLE=slussen-validator-lambda
set BUCKET=slussen-lake-qwer
set RENDERED=%TEMP%\slussen_validator_lambda_policy.json

for /f %%a in ('aws sts get-caller-identity --profile %PROFILE% --query Account --output text') do set ACCOUNT=%%a
for /f %%a in ('aws kms describe-key --key-id alias/slussen-data --profile %PROFILE% --region %REGION% --query KeyMetadata.Arn --output text') do set KMS_ARN=%%a

powershell -NoProfile -Command "(Get-Content -Raw 'infra\iam\validator_lambda_policy.json').Replace('__BUCKET__','%BUCKET%').Replace('__KMS_KEY_ARN__','%KMS_ARN%').Replace('__REGION__','%REGION%').Replace('__ACCOUNT__','%ACCOUNT%') | Set-Content -NoNewline -Encoding ascii '%RENDERED%'"
if errorlevel 1 exit /b 1

aws iam get-role --role-name %ROLE% --profile %PROFILE% >nul 2>&1
if errorlevel 1 (
    aws iam create-role --role-name %ROLE% --assume-role-policy-document file://infra/iam/validator_lambda_trust.json --description "Slussen contract gate Lambda" --profile %PROFILE% --query Role.RoleName --output text
) else (
    echo Role %ROLE% already exists
)

aws iam put-role-policy --role-name %ROLE% --policy-name slussen-validator-lambda-access --policy-document "file://%RENDERED%" --profile %PROFILE%
set RESULT=%errorlevel%
del "%RENDERED%"
if not "%RESULT%"=="0" exit /b 1
echo Policy attached to %ROLE%
endlocal