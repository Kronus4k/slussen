@echo off
setlocal
set PROFILE=slussen-de
set BUCKET=slussen-lake-qwer
set CONFIG=infra\s3\lake_lifecycle.json

python -c "import json, sys; rules = json.load(open(sys.argv[1]))['Rules']; print('Rules in file:', ', '.join(r['ID'] for r in rules))" %CONFIG%
if errorlevel 1 exit /b 1

aws s3api put-bucket-lifecycle-configuration --bucket %BUCKET% --lifecycle-configuration file://%CONFIG% --profile %PROFILE% > nul
if errorlevel 1 exit /b 1

aws s3api get-bucket-lifecycle-configuration --bucket %BUCKET% --profile %PROFILE% --query "Rules[].[ID,Status,Filter.Prefix]" --output text
endlocal