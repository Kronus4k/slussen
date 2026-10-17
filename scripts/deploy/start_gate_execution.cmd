@echo off
setlocal
set PROFILE=slussen-de
set REGION=eu-north-1
set NAME=slussen-contract-gate
set BUCKET=slussen-lake-qwer
set KEY=%~1
set EVENT=%TEMP%\slussen_gate_event.json
if "%KEY%"=="" (
    echo Usage: start_gate_execution.cmd "SUCCESS_MARKER_KEY"   ^(quotes required: keys contain =^)
    exit /b 1
)

for /f %%a in ('aws sts get-caller-identity --profile %PROFILE% --query Account --output text') do set ACCOUNT=%%a
set SM_ARN=arn:aws:states:%REGION%:%ACCOUNT%:stateMachine:%NAME%

echo {"detail":{"bucket":{"name":"%BUCKET%"},"object":{"key":"%KEY%"}}}> "%EVENT%"

for /f %%a in ('aws stepfunctions start-execution --state-machine-arn %SM_ARN% --input "file://%EVENT%" --profile %PROFILE% --region %REGION% --query executionArn --output text') do set EXEC_ARN=%%a
del "%EVENT%"
if "%EXEC_ARN%"=="" exit /b 1

:wait
timeout /t 3 /nobreak >nul
for /f %%s in ('aws stepfunctions describe-execution --execution-arn %EXEC_ARN% --profile %PROFILE% --region %REGION% --query status --output text') do set STATUS=%%s
if "%STATUS%"=="RUNNING" goto wait

echo Execution finished: %STATUS%
aws stepfunctions describe-execution --execution-arn %EXEC_ARN% --profile %PROFILE% --region %REGION% --query output --output text
endlocal