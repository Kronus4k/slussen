@echo off
setlocal
set PROFILE=slussen-de
set REGION=eu-north-1
set REPO=slussen-validator

aws ecr describe-repositories --repository-names %REPO% --profile %PROFILE% --region %REGION% >nul 2>&1
if errorlevel 1 (
    aws ecr create-repository --repository-name %REPO% --image-tag-mutability IMMUTABLE --image-scanning-configuration scanOnPush=true --encryption-configuration encryptionType=AES256 --profile %PROFILE% --region %REGION% --query repository.repositoryName --output text
) else (
    echo Repository %REPO% already exists
)

aws ecr put-lifecycle-policy --repository-name %REPO% --lifecycle-policy-text file://infra/ecr/validator_lifecycle.json --profile %PROFILE% --region %REGION% --query repositoryName --output text
endlocal