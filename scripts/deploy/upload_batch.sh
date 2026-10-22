#!/usr/bin/env bash
set -euo pipefail
export MSYS_NO_PATHCONV=1

profile="slussen-de"
bucket="slussen-lake-qwer"
prefix="${1:-}"
dryrun="${2:-}"

usage() {
  echo 'Usage: upload_batch.sh "landing/.../batch=..." [--dryrun]' >&2
  exit 1
}

[[ -z "$prefix" ]] && usage
[[ -n "$dryrun" && "$dryrun" != "--dryrun" ]] && usage
prefix="${prefix%/}"
if [[ "$prefix" != landing/* ]]; then
  echo "prefix must start with landing/" >&2
  exit 1
fi
local_dir="local_data/${prefix}"
if [[ ! -f "${local_dir}/_SUCCESS" ]]; then
  echo "no _SUCCESS in ${local_dir}: refusing to upload a batch without its marker" >&2
  exit 1
fi

aws s3 cp "$local_dir" "s3://${bucket}/${prefix}" --recursive --exclude "_SUCCESS" --profile "$profile" ${dryrun:+"$dryrun"}
aws s3 cp "${local_dir}/_SUCCESS" "s3://${bucket}/${prefix}/_SUCCESS" --profile "$profile" ${dryrun:+"$dryrun"}