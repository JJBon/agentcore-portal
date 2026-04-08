variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment (dev/staging/prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "domain_name" {
  description = "Root domain name"
  type        = string
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID"
  type        = string
}

variable "agent_subdomain" {
  description = "Subdomain for agent"
  type        = string
  default     = "agent-3lo"
}

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
  description = "Cognito domain"
  type        = string
}

variable "cognito_issuer" {
  description = "Cognito issuer URL"
  type        = string
}

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
  description = "AgentCore Identity GitHub provider name"
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

variable "inference_profile_id" {
  description = "Bedrock inference profile ID"
  type        = string
}

variable "enable_waf" {
  description = "Enable AWS WAF protection"
  type        = bool
  default     = false
}
