@echo off
setlocal
set PROFILE=slussen-de
set REGION=eu-north-1
set FUNCTION=slussen-validator
set ROLE=slussen-validator-lambda
set REPO=slussen-validator
set LOG_GROUP=/aws/lambda/%FUNCTION%
set TAG=%~1
if "%TAG%"=="" (
    echo Usage: 08_lambda_validator.cmd IMAGE_TAG
    exit /b 1
)

for /f %%a in ('aws sts get-caller-identity --profile %PROFILE% --query Account --output text') do set ACCOUNT=%%a
for /f %%a in ('aws ecr describe-images --repository-name %REPO% --image-ids imageTag^=%TAG% --profile %PROFILE% --region %REGION% --query "imageDetails[0].imageDigest" --output text') do set DIGEST=%%a
if "%DIGEST%"=="" exit /b 1
set IMAGE_URI=%ACCOUNT%.dkr.ecr.%REGION%.amazonaws.com/%REPO%@%DIGEST%
set ROLE_ARN=arn:aws:iam::%ACCOUNT%:role/%ROLE%

aws logs create-log-group --log-group-name %LOG_GROUP% --profile %PROFILE% --region %REGION% 2>nul
aws logs put-retention-policy --log-group-name %LOG_GROUP% --retention-in-days 14 --profile %PROFILE% --region %REGION%
if errorlevel 1 exit /b 1

aws lambda get-function --function-name %FUNCTION% --profile %PROFILE% --region %REGION% >nul 2>&1
if errorlevel 1 (
    aws lambda create-function --function-name %FUNCTION% --package-type Image --code ImageUri=%IMAGE_URI% --role %ROLE_ARN% --architectures x86_64 --memory-size 1024 --timeout 300 --description "Slussen contract gate" --profile %PROFILE% --region %REGION% --query FunctionName --output text
    aws lambda wait function-active-v2 --function-name %FUNCTION% --profile %PROFILE% --region %REGION%
) else (
    aws lambda update-function-code --function-name %FUNCTION% --image-uri %IMAGE_URI% --profile %PROFILE% --region %REGION% --query FunctionName --output text
    aws lambda wait function-updated-v2 --function-name %FUNCTION% --profile %PROFILE% --region %REGION%
)
echo Function %FUNCTION% is on image %TAG%
endlocal