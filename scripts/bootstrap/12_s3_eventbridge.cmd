@echo off
setlocal
set PROFILE=slussen-de
set BUCKET=slussen-lake-qwer
set QUEUE_ARN=%~1
set RENDERED=%TEMP%\slussen_lake_notifications.json
if "%QUEUE_ARN%"=="" (
    echo Usage: 12_s3_eventbridge.cmd ^<Snowpipe notification_channel ARN from SHOW PIPES^>
    exit /b 1
)

powershell -NoProfile -Command "(Get-Content -Raw 'infra\s3\lake_notifications.json').Replace('__SNOWPIPE_QUEUE_ARN__','%QUEUE_ARN%') | Set-Content -NoNewline -Encoding ascii '%RENDERED%'"
if errorlevel 1 exit /b 1

aws s3api put-bucket-notification-configuration --bucket %BUCKET% --notification-configuration "file://%RENDERED%" --profile %PROFILE%
set RESULT=%errorlevel%
del "%RENDERED%"
if not "%RESULT%"=="0" exit /b 1
aws s3api get-bucket-notification-configuration --bucket %BUCKET% --profile %PROFILE% --query "{eventbridge: EventBridgeConfiguration, queues: QueueConfigurations[].[Id, Filter.Key.FilterRules[0].Value, Filter.Key.FilterRules[1].Value]}" --output json
endlocal