# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for ALB"
  type        = list(string)
}

variable "access_logs_bucket_name" {
  description = "S3 bucket name for ALB access logs"
  type        = string
}

variable "domain_name" {
  description = "Full domain name for the application (e.g., agent-3lo.example.com)"
  type        = string
}

variable "subdomain" {
  description = "Subdomain for Route53 record (e.g., agent-3lo)"
  type        = string
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID"
  type        = string
}

# OIDC Configuration
variable "oidc_issuer" {
  description = "OIDC issuer URL"
  type        = string
}

variable "oidc_authorization_endpoint" {
  description = "OIDC authorization endpoint URL"
  type        = string
}

variable "oidc_token_endpoint" {
  description = "OIDC token endpoint URL"
  type        = string
}

variable "oidc_user_info_endpoint" {
  description = "OIDC user info endpoint URL"
  type        = string
}

variable "oidc_client_id" {
  description = "OIDC client ID"
  type        = string
  sensitive   = true
}

variable "oidc_client_secret" {
  description = "OIDC client secret"
  type        = string
  sensitive   = true
}

variable "oidc_scope" {
  description = "OIDC scope"
  type        = string
  default     = "openid email profile"
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
