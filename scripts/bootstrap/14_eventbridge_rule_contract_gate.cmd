@echo off
setlocal
set PROFILE=slussen-de
set REGION=eu-north-1
set RULE=slussen-contract-gate-batch-complete
set STATE_MACHINE=slussen-contract-gate
set ROLE=slussen-contract-gate-events

for /f %%a in ('aws sts get-caller-identity --profile %PROFILE% --query Account --output text') do set ACCOUNT=%%a
if "%ACCOUNT%"=="" exit /b 1
set SM_ARN=arn:aws:states:%REGION%:%ACCOUNT%:stateMachine:%STATE_MACHINE%
set ROLE_ARN=arn:aws:iam::%ACCOUNT%:role/%ROLE%

aws events put-rule --name %RULE% --event-pattern file://infra/eventbridge/contract_gate_rule.json --state ENABLED --description "Start the contract gate when a landing batch is complete" --profile %PROFILE% --region %REGION% >nul
if errorlevel 1 exit /b 1

aws events put-targets --rule %RULE% --targets "Id=contract-gate,Arn=%SM_ARN%,RoleArn=%ROLE_ARN%,RetryPolicy={MaximumRetryAttempts=10,MaximumEventAgeInSeconds=3600}" --profile %PROFILE% --region %REGION% --query FailedEntryCount --output text
echo Rule %RULE% points at %STATE_MACHINE%
endlocal