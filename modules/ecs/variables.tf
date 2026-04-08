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

variable "private_subnet_ids" {
  description = "List of private subnet IDs for ECS services"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security group ID of the ALB"
  type        = string
}

variable "agent_target_group_arn" {
  description = "Target group ARN for agent service"
  type        = string
}

variable "session_binding_target_group_arn" {
  description = "Target group ARN for session binding service"
  type        = string
}

# ECS Configuration
variable "agent_image" {
  description = "Docker image for agent service"
  type        = string
}

variable "session_binding_image" {
  description = "Docker image for session binding service"
  type        = string
}

variable "agent_cpu" {
  description = "CPU units for agent task"
  type        = number
  default     = 512
}

variable "agent_memory" {
  description = "Memory (MB) for agent task"
  type        = number
  default     = 1024
}

variable "session_binding_cpu" {
  description = "CPU units for session binding task"
  type        = number
  default     = 256
}

variable "session_binding_memory" {
  description = "Memory (MB) for session binding task"
  type        = number
  default     = 512
}

variable "agent_desired_count" {
  description = "Desired number of agent service tasks"
  type        = number
  default     = 1
}

variable "session_binding_desired_count" {
  description = "Desired number of session binding service tasks"
  type        = number
  default     = 1
}

# Storage Configuration
variable "sessions_bucket_name" {
  description = "S3 bucket name for sessions"
  type        = string
}

variable "sessions_bucket_arn" {
  description = "S3 bucket ARN for sessions"
  type        = string
}

variable "sessions_kms_key_arn" {
  description = "KMS key ARN for S3 bucket encryption"
  type        = string
}

# KMS Configuration
variable "kms_key_arn" {
  description = "KMS key ARN for CloudWatch Logs and Session Binding"
  type        = string
}

# Identity Configuration
variable "identity_aws_region" {
  description = "AWS region where AgentCore Workload Identity is deployed"
  type        = string
}

variable "workload_identity_name" {
  description = "AgentCore Workload Identity name"
  type        = string
}

variable "github_provider_name" {
  description = "GitHub OAuth provider name"
  type        = string
}

# Application Configuration
variable "session_binding_url" {
  description = "Session binding URL (e.g., https://agent-3lo.example.com/oauth2/session-binding)"
  type        = string
}

variable "inference_profile_id" {
  description = "Bedrock inference profile ID"
  type        = string
}

variable "github_api_base" {
  description = "GitHub API base URL"
  type        = string
  default     = "https://api.github.com"
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
