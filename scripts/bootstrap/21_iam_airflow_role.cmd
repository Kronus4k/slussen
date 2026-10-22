@echo off
setlocal
set AWS_PROFILE=slussen-admin
for /f %%a in ('aws sts get-caller-identity --query Account --output text') do set ACCOUNT_ID=%%a
if not defined ACCOUNT_ID (echo could not read the account id & exit /b 1)
set "TRUST=%TEMP%\slussen-airflow-trust.json"
set "POLICY=%TEMP%\slussen-airflow-policy.json"
powershell -NoProfile -Command "(Get-Content -Raw 'infra\iam\airflow_role_trust.json').Replace('__ACCOUNT_ID__','%ACCOUNT_ID%') | Set-Content -NoNewline -Encoding ascii '%TRUST%'"
powershell -NoProfile -Command "(Get-Content -Raw 'infra\iam\airflow_role_policy.json').Replace('__ACCOUNT_ID__','%ACCOUNT_ID%') | Set-Content -NoNewline -Encoding ascii '%POLICY%'"
aws iam get-role --role-name slussen-airflow >nul 2>&1
if errorlevel 1 (
  aws iam create-role --role-name slussen-airflow --assume-role-policy-document "file://%TRUST%" --max-session-duration 3600 --description "Airflow tasks, assumed from the DataEngineer SSO session" --query Role.RoleName --output text
) else (
  aws iam update-assume-role-policy --role-name slussen-airflow --policy-document "file://%TRUST%"
)
if errorlevel 1 (del "%TRUST%" "%POLICY%" & echo role create or update failed & exit /b 1)
aws iam put-role-policy --role-name slussen-airflow --policy-name slussen-airflow-access --policy-document "file://%POLICY%"
if errorlevel 1 (del "%TRUST%" "%POLICY%" & echo policy update failed & exit /b 1)
del "%TRUST%" "%POLICY%"
echo slussen-airflow role ready
endlocal