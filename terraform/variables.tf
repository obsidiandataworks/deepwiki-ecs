
variable "aws_region"         { type = string }
variable "app_name"           { type = string }
variable "ecr_repo"           { type = string }
variable "image_tag"          { type = string }
variable "vpc_id"             { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "public_subnet_ids"  { type = list(string) }
variable "alb_acm_cert_arn"   { type = string }

variable "cpu"    { type = number default = 512 }
variable "memory" { type = number default = 1024 }
variable "desired_count" { type = number default = 1 }
variable "min_count"     { type = number default = 1 }
variable "max_count"     { type = number default = 3 }
