@echo off
rem Run with call so && and || see the exit code: call scripts\checks\no_account_id.cmd [--network]
setlocal
for /f %%a in ('aws sts get-caller-identity --profile slussen-de --query Account --output text 2^>nul') do set ACCT=%%a
if not defined ACCT (
  echo FAIL: account ID lookup failed, run aws sso login first
  exit /b 2
)
set FOUND=0
call :check "%ACCT%" "account id"
call :check "sf-snowpipe" "snowpipe queue name"
call :check "arn:aws:sqs" "sqs arn"
call :check "arn:aws:kms" "kms arn"
if /i "%~1"=="--network" (
  call :check "subnet-" "subnet id"
  call :check "sg-0" "security group id"
  call :check "vpc-0" "vpc id"
)
if "%FOUND%"=="0" (
  echo CLEAN
  exit /b 0
)
echo FOUND: fix the files listed above before committing
exit /b 1

:check
git grep --cached -I -F -l -e %1 -- . ":(exclude)scripts/checks/*" > "%TEMP%\slussen_check.txt" 2>&1
if errorlevel 2 (
  echo ERROR  %~2
  set FOUND=1
) else if errorlevel 1 (
  echo CLEAN  %~2
) else (
  echo FOUND  %~2 in:
  type "%TEMP%\slussen_check.txt"
  set FOUND=1
)
del "%TEMP%\slussen_check.txt" 2>nul
exit /b 0