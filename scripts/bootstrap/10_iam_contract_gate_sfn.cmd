@echo off
setlocal
set PROFILE=slussen-admin
set REGION=eu-north-1
set ROLE=slussen-contract-gate-sfn
set BUCKET=slussen-lake-qwer
set TRUST=%TEMP%\slussen_sfn_trust.json
set POLICY=%TEMP%\slussen_sfn_policy.json

for /f %%a in ('aws sts get-caller-identity --profile %PROFILE% --query Account --output text') do set ACCOUNT=%%a
if "%ACCOUNT%"=="" exit /b 1

powershell -NoProfile -Command "(Get-Content -Raw 'infra\iam\contract_gate_sfn_trust.json').Replace('__ACCOUNT__','%ACCOUNT%') | Set-Content -NoNewline -Encoding ascii '%TRUST%'"
powershell -NoProfile -Command "(Get-Content -Raw 'infra\iam\contract_gate_sfn_policy.json').Replace('__BUCKET__','%BUCKET%').Replace('__REGION__','%REGION%').Replace('__ACCOUNT__','%ACCOUNT%') | Set-Content -NoNewline -Encoding ascii '%POLICY%'"

aws iam get-role --role-name %ROLE% --profile %PROFILE% >nul 2>&1
if errorlevel 1 (
    aws iam create-role --role-name %ROLE% --assume-role-policy-document "file://%TRUST%" --description "Slussen contract gate state machine" --profile %PROFILE% --query Role.RoleName --output text
) else (
    aws iam update-assume-role-policy --role-name %ROLE% --policy-document "file://%TRUST%" --profile %PROFILE%
    echo Role %ROLE% already exists, trust policy refreshed
)

aws iam put-role-policy --role-name %ROLE% --policy-name slussen-contract-gate-sfn-access --policy-document "file://%POLICY%" --profile %PROFILE%
set RESULT=%errorlevel%
del "%TRUST%" "%POLICY%"
if not "%RESULT%"=="0" exit /b 1
echo Policy attached to %ROLE%
endlocal