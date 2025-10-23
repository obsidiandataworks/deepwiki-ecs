
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."/terraform
terraform destroy -auto-approve   -var aws_region=${AWS_REGION:-us-east-1}   -var app_name=${APP_NAME:-deepwiki-open}   -var ecr_repo=${ECR_REPO:-deepwiki-open}   -var image_tag=${IMAGE_TAG:-latest}   -var vpc_id=${VPC_ID:?}   -var private_subnet_ids='["'"${PRIVATE_SUBNET_ID_1:?}"'","'"${PRIVATE_SUBNET_ID_2:?}"'"]'   -var public_subnet_ids='["'"${PUBLIC_SUBNET_ID_1:?}"'","'"${PUBLIC_SUBNET_ID_2:?}"'"]'   -var alb_acm_cert_arn=${ALB_ACM_CERT_ARN:?}
