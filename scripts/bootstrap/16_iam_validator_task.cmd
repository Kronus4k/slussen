@echo off
setlocal
set PROFILE=slussen-admin
set REGION=eu-north-1
set BUCKET=slussen-lake-qwer
set TRUST=%TEMP%\slussen_validator_task_trust.json
set TASK_POLICY=%TEMP%\slussen_validator_task_policy.json
set EXEC_POLICY=%TEMP%\slussen_validator_task_execution_policy.json
set FAILED=0

for /f %%a in ('aws sts get-caller-identity --profile %PROFILE% --query Account --output text') do set ACCOUNT=%%a
for /f %%a in ('aws kms describe-key --key-id alias/slussen-data --profile %PROFILE% --region %REGION% --query KeyMetadata.Arn --output text') do set KMS_ARN=%%a

powershell -NoProfile -Command "foreach ($p in @(@('infra\iam\validator_task_trust.json','%TRUST%'),@('infra\iam\validator_task_policy.json','%TASK_POLICY%'),@('infra\iam\validator_task_execution_policy.json','%EXEC_POLICY%'))) { (Get-Content -Raw $p[0]).Replace('__BUCKET__','%BUCKET%').Replace('__KMS_KEY_ARN__','%KMS_ARN%').Replace('__REGION__','%REGION%').Replace('__ACCOUNT__','%ACCOUNT%') | Set-Content -NoNewline -Encoding ascii $p[1] }"
if errorlevel 1 exit /b 1

call :ensure_role slussen-validator-task "Slussen contract gate task on ECS Fargate" "%TASK_POLICY%" slussen-validator-task-access
if errorlevel 1 set FAILED=1
call :ensure_role slussen-validator-task-execution "Slussen contract gate task execution: image pull and logs" "%EXEC_POLICY%" slussen-validator-task-execution-access
if errorlevel 1 set FAILED=1

del "%TRUST%" "%TASK_POLICY%" "%EXEC_POLICY%"
if "%FAILED%"=="1" exit /b 1
endlocal
exit /b 0

:ensure_role
aws iam get-role --role-name %1 --profile %PROFILE% >nul 2>&1
if errorlevel 1 (
    aws iam create-role --role-name %1 --assume-role-policy-document "file://%TRUST%" --description %2 --profile %PROFILE% --query Role.RoleName --output text
) else (
    aws iam update-assume-role-policy --role-name %1 --policy-document "file://%TRUST%" --profile %PROFILE%
    echo Role %1 already exists, trust policy refreshed
)
aws iam put-role-policy --role-name %1 --policy-name %4 --policy-document "file://%~3" --profile %PROFILE%
if errorlevel 1 exit /b 1
echo Policy attached to %1
exit /b 0