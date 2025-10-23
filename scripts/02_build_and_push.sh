
#!/usr/bin/env bash
set -euo pipefail
: "${AWS_REGION:=us-east-1}"
: "${ECR_REPO:=deepwiki-open}"
: "${GIT_REF:=main}"
: "${UPSTREAM_REPO:=https://github.com/AsyncFuncAI/deepwiki-open.git}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"

if [ ! -d deepwiki-open ]; then
  git clone "${UPSTREAM_REPO}" deepwiki-open
fi
cd deepwiki-open
git fetch --all --tags
git checkout "${GIT_REF}"

IMG_TAG=$(date +%Y%m%d-%H%M%S)
docker build -t "${ECR}:${IMG_TAG}" -t "${ECR}:latest" .
docker push "${ECR}:${IMG_TAG}"
docker push "${ECR}:latest"

echo "IMAGE_URI=${ECR}:${IMG_TAG}"
