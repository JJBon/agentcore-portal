# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

output "workload_name" {
  description = "AgentCore Workload Identity name"
  value       = var.workload_identity_name
}

output "workload_identity_arn" {
  description = "AgentCore Workload Identity ARN"
  value       = var.create_workload_identity ? aws_bedrockagentcore_workload_identity.main[0].workload_identity_arn : ""
}

output "github_provider_name" {
  description = "GitHub OAuth provider name"
  value       = var.github_provider_name
}

output "github_provider_arn" {
  description = "GitHub OAuth provider ARN"
  value       = var.create_github_provider ? aws_bedrockagentcore_oauth2_credential_provider.github[0].credential_provider_arn : ""
}

output "kms_key_id" {
  description = "KMS key ID for CloudWatch Logs"
  value       = aws_kms_key.main.key_id
}

output "kms_key_arn" {
  description = "KMS key ARN for CloudWatch Logs"
  value       = aws_kms_key.main.arn
}
