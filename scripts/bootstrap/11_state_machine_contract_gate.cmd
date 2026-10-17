@echo off
setlocal
set PROFILE=slussen-de
set REGION=eu-north-1
set NAME=slussen-contract-gate
set ROLE=slussen-contract-gate-sfn
set TOPIC=slussen-contract-alerts
set RENDERED=%TEMP%\slussen_contract_gate.asl.json

for /f %%a in ('aws sts get-caller-identity --profile %PROFILE% --query Account --output text') do set ACCOUNT=%%a
if "%ACCOUNT%"=="" exit /b 1
set SM_ARN=arn:aws:states:%REGION%:%ACCOUNT%:stateMachine:%NAME%
set ROLE_ARN=arn:aws:iam::%ACCOUNT%:role/%ROLE%
set TOPIC_ARN=arn:aws:sns:%REGION%:%ACCOUNT%:%TOPIC%

powershell -NoProfile -Command "(Get-Content -Raw 'infra\stepfunctions\contract_gate.asl.json').Replace('__TOPIC_ARN__','%TOPIC_ARN%') | Set-Content -NoNewline -Encoding ascii '%RENDERED%'"

aws stepfunctions validate-state-machine-definition --definition "file://%RENDERED%" --type STANDARD --profile %PROFILE% --region %REGION% --query "[result, diagnostics[].message]" --output text
if errorlevel 1 goto cleanup

aws stepfunctions describe-state-machine --state-machine-arn %SM_ARN% --profile %PROFILE% --region %REGION% >nul 2>&1
if errorlevel 1 (
    aws stepfunctions create-state-machine --name %NAME% --type STANDARD --definition "file://%RENDERED%" --role-arn %ROLE_ARN% --profile %PROFILE% --region %REGION% >nul
    echo Created %NAME%
) else (
    aws stepfunctions update-state-machine --state-machine-arn %SM_ARN% --definition "file://%RENDERED%" --role-arn %ROLE_ARN% --profile %PROFILE% --region %REGION% >nul
    echo Updated %NAME%
)

:cleanup
del "%RENDERED%"
endlocal