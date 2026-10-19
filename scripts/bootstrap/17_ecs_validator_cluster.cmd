@echo off
setlocal
set PROFILE=slussen-de
set REGION=eu-north-1
set CLUSTER=slussen-gate
set LOG_GROUP=/ecs/slussen-validator
set SG_NAME=slussen-validator-task

aws logs create-log-group --log-group-name %LOG_GROUP% --profile %PROFILE% --region %REGION% >nul 2>&1
aws logs put-retention-policy --log-group-name %LOG_GROUP% --retention-in-days 14 --profile %PROFILE% --region %REGION%
if errorlevel 1 exit /b 1
echo Log group %LOG_GROUP% ready, 14 days retention

aws ecs create-cluster --cluster-name %CLUSTER% --settings name=containerInsights,value=disabled --profile %PROFILE% --region %REGION% --query cluster.status --output text
if errorlevel 1 exit /b 1

for /f %%v in ('aws ec2 describe-vpcs --filters Name^=isDefault^,Values^=true --profile %PROFILE% --region %REGION% --query Vpcs[0].VpcId --output text') do set VPC=%%v
if "%VPC%"=="" exit /b 1
if "%VPC%"=="None" exit /b 1

set SG=None
for /f %%g in ('aws ec2 describe-security-groups --filters Name^=group-name^,Values^=%SG_NAME% Name^=vpc-id^,Values^=%VPC% --profile %PROFILE% --region %REGION% --query SecurityGroups[0].GroupId --output text') do set SG=%%g
if "%SG%"=="None" (
    for /f %%g in ('aws ec2 create-security-group --group-name %SG_NAME% --description "Slussen contract gate Fargate task - no inbound and HTTPS out only" --vpc-id %VPC% --profile %PROFILE% --region %REGION% --query GroupId --output text') do set SG=%%g
)
if "%SG%"=="None" exit /b 1

aws ec2 revoke-security-group-egress --group-id %SG% --ip-permissions IpProtocol=-1,IpRanges=[{CidrIp=0.0.0.0/0}] --profile %PROFILE% --region %REGION% >nul 2>&1
aws ec2 authorize-security-group-egress --group-id %SG% --ip-permissions IpProtocol=tcp,FromPort=443,ToPort=443,IpRanges=[{CidrIp=0.0.0.0/0}] --profile %PROFILE% --region %REGION% >nul 2>&1
echo Security group %SG% in %VPC%: no inbound, outbound TCP 443 only
endlocal