output "agent_url" {
  description = "HTTPS URL to access the agent"
  value       = "https://${local.agent_fqdn}"
}

output "agent_docs_url" {
  description = "URL to agent OpenAPI documentation"
  value       = "https://${local.agent_fqdn}/docs"
}

output "alb_dns_name" {
  description = "Application Load Balancer DNS name"
  value       = module.alb.alb_dns_name
}

output "alb_arn" {
  description = "Application Load Balancer ARN"
  value       = module.alb.alb_arn
}

output "s3_sessions_bucket" {
  description = "S3 bucket name for session storage"
  value       = module.storage.sessions_bucket_name
}

output "s3_access_logs_bucket" {
  description = "S3 bucket name for access logs"
  value       = module.storage.access_logs_bucket_name
}

output "kms_key_id" {
  description = "KMS key ID for encryption"
  value       = module.storage.kms_key_id
}

output "kms_key_arn" {
  description = "KMS key ARN for encryption"
  value       = module.storage.kms_key_arn
}

output "workload_identity_name" {
  description = "AgentCore Identity workload name"
  value       = module.identity.workload_name
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs.cluster_name
}

output "ecs_cluster_arn" {
  description = "ECS cluster ARN"
  value       = module.ecs.cluster_arn
}

output "agent_service_name" {
  description = "ECS agent service name"
  value       = module.ecs.agent_service_name
}

output "session_binding_service_name" {
  description = "ECS session binding service name"
  value       = module.ecs.session_binding_service_name
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "cognito_callback_url" {
  description = "URL to add to Cognito app client callback URLs"
  value       = "https://${local.agent_fqdn}/oauth2/idpresponse"
}

output "github_session_binding_callback" {
  description = "Session binding callback URL (configured in agent)"
  value       = "https://${local.agent_fqdn}/oauth2/session-binding"
}
