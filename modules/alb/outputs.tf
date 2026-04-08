# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.main.zone_id
}

output "alb_security_group_id" {
  description = "Security group ID of the ALB"
  value       = aws_security_group.alb.id
}

output "agent_target_group_arn" {
  description = "ARN of the agent target group"
  value       = aws_lb_target_group.agent.arn
}

output "session_binding_target_group_arn" {
  description = "ARN of the session binding target group"
  value       = aws_lb_target_group.session_binding.arn
}

output "https_listener_arn" {
  description = "ARN of the HTTPS listener"
  value       = aws_lb_listener.https.arn
}

output "app_url" {
  description = "Full application URL"
  value       = "https://${var.domain_name}"
}
