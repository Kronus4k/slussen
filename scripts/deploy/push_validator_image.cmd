@echo off
setlocal
set PROFILE=slussen-de
set REGION=eu-north-1
set REPO=slussen-validator

for /f %%a in ('git status --porcelain -- src contracts lambdas docker pyproject.toml requirements.lock') do (
    echo Uncommitted changes in image sources. Commit them first so the tag matches the code.
    exit /b 1
)

for /f %%a in ('git rev-parse --short HEAD') do set TAG=%%a
for /f %%a in ('aws sts get-caller-identity --profile %PROFILE% --query Account --output text') do set ACCOUNT=%%a
set REGISTRY=%ACCOUNT%.dkr.ecr.%REGION%.amazonaws.com
set IMAGE=%REGISTRY%/%REPO%:%TAG%

aws ecr get-login-password --profile %PROFILE% --region %REGION% | docker login --username AWS --password-stdin %REGISTRY%
if errorlevel 1 exit /b 1

docker build --platform linux/amd64 --provenance=false -f docker\validator\Dockerfile -t %IMAGE% .
if errorlevel 1 exit /b 1

docker push %IMAGE%
if errorlevel 1 exit /b 1

echo Pushed tag %TAG%
aws ecr describe-images --repository-name %REPO% --image-ids imageTag=%TAG% --profile %PROFILE% --region %REGION% --query "imageDetails[0].[imageTags[0],imageDigest,imageSizeInBytes]" --output text
endlocal