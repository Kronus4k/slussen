@echo off
setlocal
set PROFILE=slussen-de
set REGION=eu-north-1
set BUCKET=slussen-lake-qwer
set DATABASE=slussen_lake
set WORKGROUP=slussen

for /f %%a in ('aws kms describe-key --key-id alias/slussen-data --profile %PROFILE% --region %REGION% --query KeyMetadata.Arn --output text') do set KMS_ARN=%%a
if "%KMS_ARN%"=="" exit /b 1

aws glue get-database --name %DATABASE% --profile %PROFILE% --region %REGION% >nul 2>&1
if errorlevel 1 (
    aws glue create-database --database-input "Name=%DATABASE%,Description=Contract-validated Parquet tables of the Slussen lake" --profile %PROFILE% --region %REGION%
    if errorlevel 1 exit /b 1
    echo Created Glue database %DATABASE%
) else (
    echo Glue database %DATABASE% already exists
)

aws athena get-work-group --work-group %WORKGROUP% --profile %PROFILE% --region %REGION% >nul 2>&1
if errorlevel 1 (
    aws athena create-work-group --name %WORKGROUP% --description "Slussen lake queries: encrypted results, 1 GB scan limit per query" --configuration "ResultConfiguration={OutputLocation=s3://%BUCKET%/athena-results/,EncryptionConfiguration={EncryptionOption=SSE_KMS,KmsKey=%KMS_ARN%}},EnforceWorkGroupConfiguration=true,PublishCloudWatchMetricsEnabled=false,BytesScannedCutoffPerQuery=1073741824,EngineVersion={SelectedEngineVersion=AUTO}" --profile %PROFILE% --region %REGION%
    if errorlevel 1 exit /b 1
    echo Created Athena workgroup %WORKGROUP%
) else (
    echo Athena workgroup %WORKGROUP% already exists
)
endlocal