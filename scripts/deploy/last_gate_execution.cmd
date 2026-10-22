@echo off
setlocal
set PROFILE=slussen-de
set REGION=eu-north-1
set NAME=slussen-contract-gate
set SINCE=%~1
if "%SINCE%"=="" set SINCE=10m
set "OUT=%TEMP%\slussen_last_gate.txt"
set "IN=%TEMP%\slussen_last_gate_input.json"

for /f %%a in ('aws sts get-caller-identity --profile %PROFILE% --query Account --output text') do set ACCOUNT=%%a
if "%ACCOUNT%"=="" (echo could not read the account id & exit /b 1)
set SM_ARN=arn:aws:states:%REGION%:%ACCOUNT%:stateMachine:%NAME%

for /f %%e in ('aws stepfunctions list-executions --state-machine-arn %SM_ARN% --max-results 1 --profile %PROFILE% --region %REGION% --query "executions[0].executionArn" --output text') do set EXEC_ARN=%%e
if "%EXEC_ARN%"=="" exit /b 1

aws stepfunctions describe-execution --execution-arn %EXEC_ARN% --profile %PROFILE% --region %REGION% --query input --output text > "%IN%"
(
  aws stepfunctions describe-execution --execution-arn %EXEC_ARN% --profile %PROFILE% --region %REGION% --query "[status, error, cause]" --output text
  powershell -NoProfile -Command "'key ' + (Get-Content -Raw '%IN%' | ConvertFrom-Json).detail.object.key"
  aws stepfunctions get-execution-history --execution-arn %EXEC_ARN% --reverse-order --max-results 8 --profile %PROFILE% --region %REGION% --query "events[].[id, type, stateEnteredEventDetails.name]" --output text
  aws stepfunctions get-execution-history --execution-arn %EXEC_ARN% --profile %PROFILE% --region %REGION% --query "events[?type=='TaskFailed'].taskFailedEventDetails.[resourceType, error, cause]" --output text
  echo --- Lambda logs, last %SINCE% ---
  aws logs tail /aws/lambda/slussen-validator --since %SINCE% --profile %PROFILE% --region %REGION% --format short
) > "%OUT%" 2>&1
del "%IN%"
powershell -NoProfile -Command "(Get-Content -Raw '%OUT%') -replace '%ACCOUNT%','************' -replace '\b\d{1,3}(\.\d{1,3}){3}\b','x.x.x.x'"
del "%OUT%"
endlocal