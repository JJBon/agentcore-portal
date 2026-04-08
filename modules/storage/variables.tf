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

variable "account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "session_lifecycle_glacier_days" {
  description = "Number of days before transitioning sessions to Glacier"
  type        = number
  default     = 30
}

variable "session_lifecycle_expire_days" {
  description = "Number of days before expiring sessions"
  type        = number
  default     = 90
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
