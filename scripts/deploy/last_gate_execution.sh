#!/usr/bin/env bash
set -euo pipefail
export MSYS_NO_PATHCONV=1

profile="slussen-de"
region="eu-north-1"
machine="slussen-contract-gate"
since="${1:-10m}"

account="$(aws sts get-caller-identity --profile "$profile" --query Account --output text)"
account="${account//$'\r'/}"
if [[ -z "$account" ]]; then
  echo "could not read the account id" >&2
  exit 1
fi
sm_arn="arn:aws:states:${region}:${account}:stateMachine:${machine}"

sfn() { aws stepfunctions "$@" --profile "$profile" --region "$region"; }

mask() {
  sed -E -e "s/${account}/************/g" -e 's/\b[0-9]{1,3}(\.[0-9]{1,3}){3}\b/x.x.x.x/g'
}

exec_arn="$(sfn list-executions --state-machine-arn "$sm_arn" --max-results 1 --query "executions[0].executionArn" --output text)"
exec_arn="${exec_arn//$'\r'/}"
if [[ -z "$exec_arn" || "$exec_arn" == "None" ]]; then
  echo "no executions found" >&2
  exit 1
fi

{
  sfn describe-execution --execution-arn "$exec_arn" --query "[status, error, cause]" --output text
  input="$(sfn describe-execution --execution-arn "$exec_arn" --query input --output text)"
  key="$(printf '%s' "$input" | grep -o '"key"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n 1 | sed -E 's/.*"([^"]*)"$/\1/' || true)"
  echo "key ${key:-unknown}"
  sfn get-execution-history --execution-arn "$exec_arn" --reverse-order --max-results 8 --query "events[].[id, type, stateEnteredEventDetails.name]" --output text
  sfn get-execution-history --execution-arn "$exec_arn" --query "events[?type=='TaskFailed'].taskFailedEventDetails.[resourceType, error, cause]" --output text
  echo "--- Lambda logs, last ${since} ---"
  aws logs tail /aws/lambda/slussen-validator --since "$since" --profile "$profile" --region "$region" --format short
} 2>&1 | mask