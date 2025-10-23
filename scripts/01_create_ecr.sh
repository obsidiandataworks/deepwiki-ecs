
#!/usr/bin/env bash
set -euo pipefail
: "${AWS_REGION:=us-east-1}"
: "${ECR_REPO:=deepwiki-open}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

aws ecr describe-repositories --repository-names "$ECR_REPO" --region "$AWS_REGION" >/dev/null 2>&1 ||   aws ecr create-repository --repository-name "$ECR_REPO" --image-scanning-configuration scanOnPush=true --region "$AWS_REGION"

aws ecr get-login-password --region "$AWS_REGION"  | docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo "ECR: ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"
