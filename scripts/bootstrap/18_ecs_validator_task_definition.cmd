@echo off
setlocal
set PROFILE=slussen-de
set REGION=eu-north-1
set TAG=%~1
set RENDERED=%TEMP%\slussen_validator_task_definition.json
if "%TAG%"=="" (
    echo Usage: 18_ecs_validator_task_definition.cmd ^<image tag^>
    exit /b 1
)

for /f %%a in ('aws sts get-caller-identity --profile %PROFILE% --query Account --output text') do set ACCOUNT=%%a

aws ecr describe-images --repository-name slussen-validator --image-ids imageTag=%TAG% --profile %PROFILE% --region %REGION% --query imageDetails[0].imageTags --output text >nul 2>&1
if errorlevel 1 (
    echo Image tag %TAG% not found in slussen-validator
    exit /b 1
)

powershell -NoProfile -Command "(Get-Content -Raw 'infra\ecs\validator_task_definition.json').Replace('__ACCOUNT__','%ACCOUNT%').Replace('__REGION__','%REGION%').Replace('__IMAGE_TAG__','%TAG%') | Set-Content -NoNewline -Encoding ascii '%RENDERED%'"
if errorlevel 1 exit /b 1

aws ecs register-task-definition --cli-input-json "file://%RENDERED%" --profile %PROFILE% --region %REGION% --query "taskDefinition.[family, revision, status]" --output text
set RESULT=%errorlevel%
del "%RENDERED%"
if not "%RESULT%"=="0" exit /b 1
endlocal