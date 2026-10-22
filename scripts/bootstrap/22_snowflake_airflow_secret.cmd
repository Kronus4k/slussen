@echo off
setlocal
if "%~1"=="" (echo usage: 22_snowflake_airflow_secret.cmd SNOWFLAKE_ACCOUNT_IDENTIFIER & exit /b 1)
if not exist scripts\airflow\make_snowflake_secret.py (echo run from the repo root & exit /b 1)
set "OUT=%TEMP%\slussen-airflow-secret"
if exist "%OUT%" rmdir /s /q "%OUT%"
mkdir "%OUT%"
docker run --rm -v "%CD%\scripts\airflow:/app:ro" -v "%OUT%:/out" --entrypoint python slussen-airflow:dev /app/make_snowflake_secret.py --account "%~1"
if errorlevel 1 (rmdir /s /q "%OUT%" & echo key generation failed & exit /b 1)
set "NAME=slussen/airflow/connections/snowflake_default"
aws secretsmanager describe-secret --secret-id %NAME% --profile slussen-de >nul 2>&1
if errorlevel 1 (
  aws secretsmanager create-secret --name %NAME% --description "Airflow Snowflake connection for SVC_AIRFLOW" --secret-string "file://%OUT%\secret.json" --profile slussen-de --query Name --output text
) else (
  aws secretsmanager put-secret-value --secret-id %NAME% --secret-string "file://%OUT%\secret.json" --profile slussen-de --query VersionId --output text
)
if errorlevel 1 (rmdir /s /q "%OUT%" & echo secret update failed & exit /b 1)
del "%OUT%\secret.json"
echo secret stored; next: run %%TEMP%%\slussen-airflow-secret\set_public_key.sql in Snowsight
endlocal