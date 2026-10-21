#!/usr/bin/env bash
set -euo pipefail

account_id="${ACCOUNT_ID:-}"
if [[ -z "$account_id" ]]; then
  account_id="$(aws sts get-caller-identity --profile slussen-de --query Account --output text 2>/dev/null || true)"
fi
if [[ -z "$account_id" ]]; then
  echo "FAIL: no account ID; set ACCOUNT_ID or run aws sso login first"
  exit 2
fi

found=0
exclude=":(exclude)scripts/checks/*"

check() {
  local mode="$1" pattern="$2" label="$3" files rc
  if files="$(git grep --cached -I -l "$mode" -e "$pattern" -- . "$exclude")"; then
    echo "FOUND  $label in:"
    echo "$files"
    found=1
  else
    rc=$?
    if [[ $rc -eq 1 ]]; then
      echo "CLEAN  $label"
    else
      echo "ERROR  $label"
      found=1
    fi
  fi
}

check -F "$account_id" "account id"
check -F "sf-snowpipe" "snowpipe queue name"
check -F "arn:aws:sqs" "sqs arn"
check -F "arn:aws:kms" "kms arn"
check -E "arn:aws:[a-z0-9-]*:[a-z0-9-]*:[0-9]{12}:" "arn with account number"
check -E "[0-9]{12}\.dkr\.ecr" "ecr host with account number"
if [[ "${1:-}" == "--network" ]]; then
  check -F "subnet-" "subnet id"
  check -F "sg-0" "security group id"
  check -F "vpc-0" "vpc id"
fi

if [[ $found -eq 0 ]]; then
  echo "CLEAN"
  exit 0
fi
echo "FOUND: fix the files listed above before committing"
exit 1