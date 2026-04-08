# Project Configuration
variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
}

variable "identity_aws_region" {
  description = "AWS region for AgentCore Identity (may differ from main region)"
  type        = string
  default     = null
}

# DNS Configuration
variable "domain_name" {
  description = "Root domain name (e.g., example.com)"
  type        = string
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID"
  type        = string
}

variable "agent_subdomain" {
  description = "Subdomain for the agent (e.g., agent-3lo)"
  type        = string
  default     = "agent-3lo"
}

# Cognito OIDC Configuration
variable "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  type        = string
}

variable "cognito_client_id" {
  description = "Cognito App Client ID"
  type        = string
}

variable "cognito_client_secret" {
  description = "Cognito App Client Secret"
  type        = string
  sensitive   = true
}

variable "cognito_domain" {
  description = "Cognito domain (e.g., your-app.auth.us-east-1.amazoncognito.com)"
  type        = string
}

variable "cognito_issuer" {
  description = "Cognito issuer URL (e.g., https://cognito-idp.us-east-1.amazonaws.com/us-east-1_ABC123)"
  type        = string
}

variable "cognito_user_info_endpoint" {
  description = "Cognito UserInfo endpoint"
  type        = string
  default     = null
}

variable "oidc_scope" {
  description = "OAuth scopes for OIDC"
  type        = string
  default     = "openid email profile"
}

# AgentCore Identity Configuration
variable "workload_identity_name" {
  description = "AgentCore Workload Identity name"
  type        = string
}

variable "create_workload_identity" {
  description = "Whether to create a new workload identity (true) or reference existing (false)"
  type        = bool
  default     = false
}

variable "github_provider_name" {
  description = "AgentCore Identity OAuth provider name for GitHub"
  type        = string
}

variable "create_github_provider" {
  description = "Whether to create GitHub OAuth provider"
  type        = bool
  default     = false
}

variable "github_client_id" {
  description = "GitHub OAuth App Client ID (required if create_github_provider is true)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "github_client_secret" {
  description = "GitHub OAuth App Client Secret (required if create_github_provider is true)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "github_api_base" {
  description = "GitHub API base URL"
  type        = string
  default     = "https://api.github.com"
}

# Bedrock Configuration
variable "inference_profile_id" {
  description = "Bedrock inference profile ID"
  type        = string
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones (leave null for automatic selection)"
  type        = list(string)
  default     = null
}

# ECS Configuration
variable "agent_task_cpu" {
  description = "CPU units for agent task (256, 512, 1024, 2048, 4096)"
  type        = number
  default     = 512
}

variable "agent_task_memory" {
  description = "Memory for agent task in MB (512, 1024, 2048, etc.)"
  type        = number
  default     = 1024
}

variable "agent_desired_count" {
  description = "Desired number of agent tasks"
  type        = number
  default     = 1
}

variable "session_binding_task_cpu" {
  description = "CPU units for session binding task"
  type        = number
  default     = 256
}

variable "session_binding_task_memory" {
  description = "Memory for session binding task in MB"
  type        = number
  default     = 512
}

variable "session_binding_desired_count" {
  description = "Desired number of session binding tasks"
  type        = number
  default     = 1
}

# Docker Image Configuration
variable "agent_image" {
  description = "Docker image for agent (ECR URI)"
  type        = string
}

variable "session_binding_image" {
  description = "Docker image for session binding service (ECR URI)"
  type        = string
}

# S3 Configuration
variable "session_lifecycle_glacier_days" {
  description = "Days until sessions are moved to Glacier"
  type        = number
  default     = 30
}

variable "session_lifecycle_expire_days" {
  description = "Days until sessions are expired"
  type        = number
  default     = 90
}

# WAF Configuration
variable "enable_waf" {
  description = "Enable AWS WAF for ALB"
  type        = bool
  default     = true
}

# Logging Configuration
variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

# Tags
variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}
