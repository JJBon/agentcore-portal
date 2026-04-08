locals {
  agent_fqdn              = "${var.agent_subdomain}.${var.domain_name}"
  identity_region         = coalesce(var.identity_aws_region, var.aws_region)
  cognito_user_info_endpoint = coalesce(
    var.cognito_user_info_endpoint,
    "https://${var.cognito_domain}/oauth2/userInfo"
  )
  cognito_authorization_endpoint = "https://${var.cognito_domain}/oauth2/authorize"
  cognito_token_endpoint        = "https://${var.cognito_domain}/oauth2/token"

  common_tags = merge(
    var.tags,
    {
      AgentFQDN = local.agent_fqdn
    }
  )
}

# Random suffix for unique resource names
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Data sources
data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = coalesce(var.availability_zones, slice(data.aws_availability_zones.available.names, 0, 2))

  tags = local.common_tags
}

# Storage Module (S3, KMS)
module "storage" {
  source = "./modules/storage"

  project_name                   = var.project_name
  environment                    = var.environment
  account_id                     = data.aws_caller_identity.current.account_id
  session_lifecycle_glacier_days = var.session_lifecycle_glacier_days
  session_lifecycle_expire_days  = var.session_lifecycle_expire_days

  tags = local.common_tags
}

# Secrets Manager for Cognito credentials
resource "aws_secretsmanager_secret" "cognito_credentials" {
  name = "${var.project_name}-${var.environment}-cognito-credentials-${random_string.suffix.result}"
  kms_key_id = module.storage.kms_key_id
}

resource "aws_secretsmanager_secret_version" "cognito_credentials" {
  secret_id = aws_secretsmanager_secret.cognito_credentials.id
  secret_string = jsonencode({
    client_id     = var.cognito_client_id
    client_secret = var.cognito_client_secret
  })
}

# ALB Module
module "alb" {
  source = "./modules/alb"

  project_name                 = var.project_name
  environment                  = var.environment
  vpc_id                       = module.vpc.vpc_id
  public_subnet_ids            = module.vpc.public_subnet_ids
  domain_name                  = local.agent_fqdn
  subdomain                    = var.agent_subdomain
  hosted_zone_id               = var.hosted_zone_id
  oidc_issuer                  = var.cognito_issuer
  oidc_authorization_endpoint  = local.cognito_authorization_endpoint
  oidc_token_endpoint          = local.cognito_token_endpoint
  oidc_user_info_endpoint      = local.cognito_user_info_endpoint
  oidc_client_id               = var.cognito_client_id
  oidc_client_secret           = var.cognito_client_secret
  oidc_scope                   = var.oidc_scope
  access_logs_bucket_name      = module.storage.access_logs_bucket_name

  tags = local.common_tags
}

# WAF Module
module "waf" {
  count  = var.enable_waf ? 1 : 0
  source = "./modules/waf"

  project_name = var.project_name
  environment  = var.environment
  alb_arn      = module.alb.alb_arn

  tags = local.common_tags
}

# AgentCore Identity Module
module "identity" {
  source = "./modules/identity"

  project_name             = var.project_name
  environment              = var.environment
  aws_region               = local.identity_region
  workload_identity_name   = var.workload_identity_name
  create_workload_identity = var.create_workload_identity
  github_provider_name     = var.github_provider_name
  create_github_provider   = var.create_github_provider
  github_client_id         = var.github_client_id
  github_client_secret     = var.github_client_secret
  session_binding_callback_url = "https://${local.agent_fqdn}/oauth2/session-binding"

  providers = {
    aws = aws
  }

  tags = local.common_tags
}

# ECS Module
module "ecs" {
  source = "./modules/ecs"

  project_name                     = var.project_name
  environment                      = var.environment
  identity_aws_region              = local.identity_region
  vpc_id                           = module.vpc.vpc_id
  private_subnet_ids               = module.vpc.private_subnet_ids
  alb_security_group_id            = module.alb.alb_security_group_id
  agent_target_group_arn           = module.alb.agent_target_group_arn
  session_binding_target_group_arn = module.alb.session_binding_target_group_arn
  agent_image                      = var.agent_image
  session_binding_image            = var.session_binding_image
  agent_cpu                        = var.agent_task_cpu
  agent_memory                     = var.agent_task_memory
  session_binding_cpu              = var.session_binding_task_cpu
  session_binding_memory           = var.session_binding_task_memory
  agent_desired_count              = var.agent_desired_count
  session_binding_desired_count    = var.session_binding_desired_count
  sessions_bucket_name             = module.storage.sessions_bucket_name
  sessions_bucket_arn              = module.storage.sessions_bucket_arn
  sessions_kms_key_arn             = module.storage.kms_key_arn
  kms_key_arn                      = module.identity.kms_key_arn
  workload_identity_name           = module.identity.workload_name
  github_provider_name             = var.github_provider_name
  github_api_base                  = var.github_api_base
  inference_profile_id             = var.inference_profile_id
  session_binding_url              = "https://${local.agent_fqdn}/oauth2/session-binding"

  tags = local.common_tags

  depends_on = [
    module.alb,
    module.identity
  ]
}
