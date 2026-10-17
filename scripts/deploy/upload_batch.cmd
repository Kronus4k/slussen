@echo off
setlocal
set PROFILE=slussen-de
set BUCKET=slussen-lake-qwer
set PREFIX=%~1
if "%PREFIX%"=="" (
    echo Usage: upload_batch.cmd "landing/.../batch=..."   ^(quotes required: keys contain =^)
    exit /b 1
)
set LOCAL=local_data\%PREFIX:/=\%

aws s3 cp "%LOCAL%" "s3://%BUCKET%/%PREFIX%" --recursive --exclude "_SUCCESS" --profile %PROFILE%
if errorlevel 1 exit /b 1
aws s3 cp "%LOCAL%\_SUCCESS" "s3://%BUCKET%/%PREFIX%/_SUCCESS" --profile %PROFILE%
endlocal