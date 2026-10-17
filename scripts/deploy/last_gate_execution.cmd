@echo off
setlocal
set PROFILE=slussen-de
set REGION=eu-north-1
set NAME=slussen-contract-gate

for /f %%a in ('aws sts get-caller-identity --profile %PROFILE% --query Account --output text') do set ACCOUNT=%%a
set SM_ARN=arn:aws:states:%REGION%:%ACCOUNT%:stateMachine:%NAME%

for /f %%e in ('aws stepfunctions list-executions --state-machine-arn %SM_ARN% --max-results 1 --profile %PROFILE% --region %REGION% --query "executions[0].executionArn" --output text') do set EXEC_ARN=%%e
if "%EXEC_ARN%"=="" exit /b 1

aws stepfunctions describe-execution --execution-arn %EXEC_ARN% --profile %PROFILE% --region %REGION% --query "[status, error, cause]" --output text
aws stepfunctions get-execution-history --execution-arn %EXEC_ARN% --reverse-order --max-results 8 --profile %PROFILE% --region %REGION% --query "events[].[id, type, stateEnteredEventDetails.name]" --output text
aws stepfunctions get-execution-history --execution-arn %EXEC_ARN% --profile %PROFILE% --region %REGION% --query "events[?type=='TaskFailed'].taskFailedEventDetails.[resourceType, error, cause]" --output text
aws logs tail /aws/lambda/slussen-validator --since 2h --profile %PROFILE% --region %REGION% --format short
endlocal