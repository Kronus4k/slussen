@echo off
setlocal
set "ENV_FILE=%~dp0..\..\airflow\.env"
if exist "%ENV_FILE%" (
  echo airflow\.env already exists, nothing changed
  exit /b 1
)
if not exist "%~dp0..\..\airflow" mkdir "%~dp0..\..\airflow"
for /f "delims=" %%a in ('docker run --rm --entrypoint python slussen-airflow:dev -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"') do set "FERNET=%%a"
for /f "delims=" %%a in ('docker run --rm --entrypoint python slussen-airflow:dev -c "import secrets; print(secrets.token_urlsafe(32))"') do set "JWT=%%a"
for /f "delims=" %%a in ('docker run --rm --entrypoint python slussen-airflow:dev -c "import secrets; print(secrets.token_urlsafe(18))"') do set "PW=%%a"
if not defined FERNET (echo could not generate the Fernet key & exit /b 1)
if not defined JWT (echo could not generate the JWT secret & exit /b 1)
if not defined PW (echo could not generate the password & exit /b 1)
(
  echo AIRFLOW_UID=50000
  echo FERNET_KEY=%FERNET%
  echo AIRFLOW__API_AUTH__JWT_SECRET=%JWT%
  echo _AIRFLOW_WWW_USER_USERNAME=admin
  echo _AIRFLOW_WWW_USER_PASSWORD=%PW%
) > "%ENV_FILE%"
echo airflow\.env written with 5 keys
endlocal