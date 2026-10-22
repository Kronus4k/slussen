@echo off
setlocal
set PROFILE=slussen-de
set BUCKET=slussen-lake-qwer
set PREFIX=%~1
set DRYRUN=%~2
if "%PREFIX%"=="" goto usage
if not "%DRYRUN%"=="" if not "%DRYRUN%"=="--dryrun" goto usage
if not "%PREFIX:~0,8%"=="landing/" (echo prefix must start with landing/ & exit /b 1)
set LOCAL=local_data\%PREFIX:/=\%
if not exist "%LOCAL%\_SUCCESS" (echo no _SUCCESS in %LOCAL%: refusing to upload a batch without its marker & exit /b 1)

aws s3 cp "%LOCAL%" "s3://%BUCKET%/%PREFIX%" --recursive --exclude "_SUCCESS" --profile %PROFILE% %DRYRUN%
if errorlevel 1 exit /b 1
aws s3 cp "%LOCAL%\_SUCCESS" "s3://%BUCKET%/%PREFIX%/_SUCCESS" --profile %PROFILE% %DRYRUN%
exit /b %errorlevel%

:usage
echo Usage: upload_batch.cmd "landing/.../batch=..." [--dryrun]   ^(quotes required: keys contain =^)
exit /b 1