# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

output "sessions_bucket_name" {
  description = "Sessions S3 bucket name"
  value       = aws_s3_bucket.sessions.id
}

output "sessions_bucket_arn" {
  description = "Sessions S3 bucket ARN"
  value       = aws_s3_bucket.sessions.arn
}

output "access_logs_bucket_name" {
  description = "Access logs S3 bucket name"
  value       = aws_s3_bucket.access_logs.id
}

output "access_logs_bucket_arn" {
  description = "Access logs S3 bucket ARN"
  value       = aws_s3_bucket.access_logs.arn
}

output "kms_key_id" {
  description = "KMS key ID"
  value       = aws_kms_key.sessions.key_id
}

output "kms_key_arn" {
  description = "KMS key ARN"
  value       = aws_kms_key.sessions.arn
}
