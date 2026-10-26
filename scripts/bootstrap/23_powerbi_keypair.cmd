@echo off
rem Generates the encrypted RSA key pair for the Snowflake service user SVC_POWERBI
rem (Power BI Desktop's native Snowflake connector accepts encrypted private keys only)
rem and prints the public key fingerprint.
rem Writes to %USERPROFILE%\.slussen\powerbi, outside the repo:
rem   passphrase.txt  random passphrase that encrypts the private key (copy it into Power BI)
rem   rsa_key.p8      private key, PKCS#8, AES-256 encrypted
rem   rsa_key.pub     public key, set on the Snowflake user
rem Prints only the fingerprint, never the key or the passphrase.
rem Rerun: safe. With an existing key it skips generation and only prints the fingerprint,
rem   so it can't rotate the key by accident. To rotate on purpose, delete the folder first,
rem   then set the new public key in Snowflake.
setlocal

if not "%~1"=="" (
  echo Usage: call scripts\bootstrap\23_powerbi_keypair.cmd   ^(no arguments^)
  exit /b 1
)

set "OPENSSL=%ProgramFiles%\Git\usr\bin\openssl.exe"
set "KEYDIR=%USERPROFILE%\.slussen\powerbi"

if not exist "%OPENSSL%" (
  echo FAIL: OpenSSL from Git for Windows not found at "%OPENSSL%"
  exit /b 1
)
if exist "%KEYDIR%\rsa_key.p8" (
  echo Key already exists in "%KEYDIR%"; printing its fingerprint only.
  goto :fingerprint
)
if not exist "%KEYDIR%" mkdir "%KEYDIR%"

rem 32 random bytes as base64: the passphrase lives only in this file.
"%OPENSSL%" rand -base64 32 > "%KEYDIR%\passphrase.txt" || goto :fail

rem Generate a 2048-bit key and write it as encrypted PKCS#8 straight away,
rem so the unencrypted key never touches the disk.
"%OPENSSL%" genrsa 2048 2>nul | "%OPENSSL%" pkcs8 -topk8 -v2 aes256 -inform PEM -out "%KEYDIR%\rsa_key.p8" -passout "file:%KEYDIR%\passphrase.txt" || goto :fail

rem The public key is derived from the encrypted private key.
"%OPENSSL%" rsa -in "%KEYDIR%\rsa_key.p8" -passin "file:%KEYDIR%\passphrase.txt" -pubout -out "%KEYDIR%\rsa_key.pub" 2>nul || goto :fail

:fingerprint
rem Same format as Snowflake's RSA_PUBLIC_KEY_FP: SHA256 of the DER public key, base64.
rem Done in plain steps with temporary files: a FOR /F over quoted paths with spaces
rem and pipes breaks at "C:\Program Files".
"%OPENSSL%" rsa -pubin -in "%KEYDIR%\rsa_key.pub" -outform DER -out "%KEYDIR%\pub.der" 2>nul || goto :fail
"%OPENSSL%" dgst -sha256 -binary -out "%KEYDIR%\pub.sha256" "%KEYDIR%\pub.der" || goto :fail
"%OPENSSL%" enc -base64 -A -in "%KEYDIR%\pub.sha256" -out "%KEYDIR%\pub.fp" || goto :fail
set "FP="
set /p FP=<"%KEYDIR%\pub.fp"
del "%KEYDIR%\pub.der" "%KEYDIR%\pub.sha256" "%KEYDIR%\pub.fp"
rem An empty fingerprint is a failure, never a pass.
if not defined FP goto :fail
echo Public key fingerprint: SHA256:%FP%
endlocal
exit /b 0

:fail
echo FAIL: key generation or fingerprint stopped; nothing was set in Snowflake
endlocal
exit /b 1