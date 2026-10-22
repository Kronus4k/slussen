#!/usr/bin/env bash
set -euo pipefail
export MSYS_NO_PATHCONV=1

profile="slussen-de"
region="eu-north-1"
machine="slussen-contract-gate"
bucket="slussen-lake-qwer"
key="${1:-}"
max_polls=200

if [[ -z "$key" || "$key" != */_SUCCESS ]]; then
  echo 'Usage: start_gate_execution.sh "landing/.../batch=.../_SUCCESS"' >&2
  exit 1
fi

account="$(aws sts get-caller-identity --profile "$profile" --query Account --output text)"
account="${account//$'\r'/}"
if [[ -z "$account" ]]; then
  echo "could not read the account id" >&2
  exit 1
fi
sm_arn="arn:aws:states:${region}:${account}:stateMachine:${machine}"

sfn() { aws stepfunctions "$@" --profile "$profile" --region "$region"; }
mask() { sed -E -e "s/${account}/************/g" -e 's/\b[0-9]{1,3}(\.[0-9]{1,3}){3}\b/x.x.x.x/g'; }

event="{\"detail\":{\"bucket\":{\"name\":\"${bucket}\"},\"object\":{\"key\":\"${key}\"}}}"
exec_arn="$(sfn start-execution --state-machine-arn "$sm_arn" --input "$event" --query executionArn --output text)"
exec_arn="${exec_arn//$'\r'/}"

status="RUNNING"
polls=0
while [[ "$status" == "RUNNING" ]]; do
  if (( polls >= max_polls )); then
    echo "still RUNNING after $(( max_polls * 3 )) s; check the console" >&2
    exit 1
  fi
  sleep 3
  polls=$(( polls + 1 ))
  status="$(sfn describe-execution --execution-arn "$exec_arn" --query status --output text)"
  status="${status//$'\r'/}"
done

echo "Execution finished: ${status}"
sfn describe-execution --execution-arn "$exec_arn" --query output --output text | mask
[[ "$status" == "SUCCEEDED" ]]