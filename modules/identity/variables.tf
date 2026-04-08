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

variable "aws_region" {
  description = "AWS region for the identity resources"
  type        = string
}

variable "workload_identity_name" {
  description = "AgentCore Workload Identity name"
  type        = string
}

variable "create_workload_identity" {
  description = "Whether to create a new workload identity (true) or reference existing (false)"
  type        = bool
  default     = true
}

variable "github_provider_name" {
  description = "GitHub OAuth provider name"
  type        = string
  default     = ""
}

variable "create_github_provider" {
  description = "Whether to create GitHub OAuth provider"
  type        = bool
  default     = false
}

variable "github_client_id" {
  description = "GitHub OAuth App Client ID"
  type        = string
  default     = ""
  sensitive   = true
}

variable "github_client_secret" {
  description = "GitHub OAuth App Client Secret"
  type        = string
  default     = ""
  sensitive   = true
}

variable "session_binding_callback_url" {
  description = "Session binding callback URL for OAuth"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
