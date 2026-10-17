@echo off
setlocal
set PROFILE=slussen-de
set REGION=eu-north-1
set TOPIC=slussen-contract-alerts
set EMAIL=%~1
if "%EMAIL%"=="" (
    echo Usage: 09_sns_alerts.cmd EMAIL_ADDRESS
    exit /b 1
)

for /f %%a in ('aws sns create-topic --name %TOPIC% --profile %PROFILE% --region %REGION% --query TopicArn --output text') do set TOPIC_ARN=%%a
if "%TOPIC_ARN%"=="" exit /b 1

aws sns subscribe --topic-arn %TOPIC_ARN% --protocol email --notification-endpoint %EMAIL% --profile %PROFILE% --region %REGION% --query SubscriptionArn --output text
echo Topic %TOPIC% ready. Confirm the subscription from the email AWS just sent.
endlocal