# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# KMS Key for CloudWatch Logs and Session Binding encryption
resource "aws_kms_key" "main" {
  description             = "KMS key for CloudWatch Logs encryption and Session Binding"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAccountPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowCloudWatchLogsEncryption"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          ArnEquals = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:*"
          }
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-cwl-kms"
    }
  )
}

resource "aws_kms_alias" "main" {
  name          = "alias/agent-cwl-${var.environment}"
  target_key_id = aws_kms_key.main.key_id
}

# AgentCore Workload Identity
resource "aws_bedrockagentcore_workload_identity" "main" {
  count = var.create_workload_identity ? 1 : 0

  name   = var.workload_identity_name
  region = var.aws_region

  allowed_resource_oauth2_return_urls = var.session_binding_callback_url != "" ? [
    var.session_binding_callback_url
  ] : []
}

# GitHub OAuth2 Credential Provider
resource "aws_bedrockagentcore_oauth2_credential_provider" "github" {
  count = var.create_github_provider ? 1 : 0

  name                       = var.github_provider_name
  credential_provider_vendor = "GithubOauth2"
  region                     = var.aws_region

  oauth2_provider_config {
    github_oauth2_provider_config {
      client_id     = var.github_client_id
      client_secret = var.github_client_secret
    }
  }

  tags = merge(
    var.tags,
    {
      Name = var.github_provider_name
    }
  )
}

data "aws_caller_identity" "current" {}
