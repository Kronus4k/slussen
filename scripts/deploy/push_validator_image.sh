#!/usr/bin/env bash
set -euo pipefail
export MSYS_NO_PATHCONV=1

profile="slussen-de"
region="eu-north-1"
repo="slussen-validator"
mode="${1:-}"

if [[ -n "$mode" && "$mode" != "--build-only" ]]; then
  echo "Usage: push_validator_image.sh [--build-only]" >&2
  exit 1
fi

if [[ -n "$(git status --porcelain -- src contracts lambdas docker pyproject.toml requirements.lock)" ]]; then
  echo "Uncommitted changes in image sources. Commit them first so the tag matches the code." >&2
  exit 1
fi

tag="$(git rev-parse --short HEAD)"

if [[ "$mode" == "--build-only" ]]; then
  docker build --platform linux/amd64 --provenance=false -f docker/validator/Dockerfile -t "${repo}:${tag}" .
  echo "Built local image ${repo}:${tag} (not pushed)"
  exit 0
fi

account="$(aws sts get-caller-identity --profile "$profile" --query Account --output text)"
account="${account//$'\r'/}"
if [[ -z "$account" ]]; then
  echo "could not read the account id" >&2
  exit 1
fi
registry="${account}.dkr.ecr.${region}.amazonaws.com"
image="${registry}/${repo}:${tag}"

mask() { sed -E "s/${account}/************/g"; }

aws ecr get-login-password --profile "$profile" --region "$region" | tr -d '\r' \
  | docker login --username AWS --password-stdin "$registry" 2>&1 | mask
docker build --platform linux/amd64 --provenance=false -f docker/validator/Dockerfile -t "$image" . 2>&1 | mask
docker push "$image" 2>&1 | mask

echo "Pushed tag ${tag}"
aws ecr describe-images --repository-name "$repo" --image-ids "imageTag=${tag}" --profile "$profile" --region "$region" \
  --query "imageDetails[0].[imageTags[0],imageDigest,imageSizeInBytes]" --output text