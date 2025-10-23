
# deepwiki-open on AWS ECS (Fargate) with Amazon Bedrock

This repo deploys **deepwiki-open** to **AWS ECS Fargate**, fronted by an HTTPS ALB, with Bedrock permissions via the ECS task role.
It includes bash scripts to create an ECR repo, build/push the image, and deploy/destroy the stack via Terraform.

## Quick Start

```bash
# Prereqs: awscli, docker, terraform
aws configure set region us-east-1
export AWS_REGION=us-east-1
export VPC_ID=<vpc-...>
export PRIVATE_SUBNET_ID_1=<subnet-...>
export PRIVATE_SUBNET_ID_2=<subnet-...>
export PUBLIC_SUBNET_ID_1=<subnet-...>
export PUBLIC_SUBNET_ID_2=<subnet-...>
export ALB_ACM_CERT_ARN=arn:aws:acm:us-east-1:<acct>:certificate/<uuid>

# 1) Create ECR & login
./scripts/01_create_ecr.sh

# 2) Build and push app image from the upstream repo (or your fork)
./scripts/02_build_and_push.sh

# 3) Deploy ECS + ALB
./scripts/03_deploy.sh
# -> Outputs the ALB DNS; open https://<alb-dns>

# 4) Destroy
./scripts/99_destroy.sh
```

### Optional UI Gate
Set these in `terraform/main.tf` under `environment` to require a simple passcode at the UI:
```
DEEPWIKI_AUTH_MODE=true
DEEPWIKI_AUTH_CODE=<secret>
```

### Notes
- The container exposes the UI on port **3000**. The internal backend runs on **8001**; `SERVER_BASE_URL=http://localhost:8001` connects the front-end to the local API.
- Bedrock access is granted by the task role (`bedrock:InvokeModel*`). No static keys are baked into the container; only `AWS_REGION` is required.
- You can change autoscaling or task size in `terraform/variables.tf`.
