# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

output "cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "cluster_arn" {
  description = "ECS cluster ARN"
  value       = aws_ecs_cluster.main.arn
}

output "agent_service_name" {
  description = "Agent ECS service name"
  value       = aws_ecs_service.agent.name
}

output "session_binding_service_name" {
  description = "Session binding ECS service name"
  value       = aws_ecs_service.session_binding.name
}

output "agent_task_role_arn" {
  description = "Agent task role ARN"
  value       = aws_iam_role.agent_task.arn
}

output "session_binding_task_role_arn" {
  description = "Session binding task role ARN"
  value       = aws_iam_role.session_binding_task.arn
}

output "ecs_security_group_id" {
  description = "ECS security group ID"
  value       = aws_security_group.ecs.id
}
