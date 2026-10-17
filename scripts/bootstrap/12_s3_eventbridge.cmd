@echo off
setlocal
set PROFILE=slussen-de
set BUCKET=slussen-lake-qwer

aws s3api put-bucket-notification-configuration --bucket %BUCKET% --notification-configuration file://infra/s3/lake_notifications.json --profile %PROFILE%
if errorlevel 1 exit /b 1
aws s3api get-bucket-notification-configuration --bucket %BUCKET% --profile %PROFILE%
endlocal