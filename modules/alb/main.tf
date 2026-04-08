# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ALB Security Group
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-${var.environment}-alb-sg"
  description = "ALB security group"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-alb-sg"
    }
  )
}

# ACM Certificate
resource "aws_acm_certificate" "main" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-cert"
    }
  )
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.hosted_zone_id
}

resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  drop_invalid_header_fields = true

  access_logs {
    bucket  = var.access_logs_bucket_name
    prefix  = "alb"
    enabled = true
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-alb"
    }
  )
}

# Target Groups
resource "aws_lb_target_group" "agent" {
  name        = "${var.project_name}-${var.environment}-agent-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/ping"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  deregistration_delay = 30

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-agent-tg"
    }
  )
}

resource "aws_lb_target_group" "session_binding" {
  name        = "${var.project_name}-${var.environment}-session-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/ping"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  deregistration_delay = 30

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-session-tg"
    }
  )
}

# HTTP Listener (redirect to HTTPS)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS Listener
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.main.certificate_arn

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }
}

# Listener Rule for Agent paths with OIDC authentication
resource "aws_lb_listener_rule" "agent" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 11

  action {
    type = "authenticate-oidc"

    authenticate_oidc {
      authorization_endpoint = var.oidc_authorization_endpoint
      client_id              = var.oidc_client_id
      client_secret          = var.oidc_client_secret
      issuer                 = var.oidc_issuer
      token_endpoint         = var.oidc_token_endpoint
      user_info_endpoint     = var.oidc_user_info_endpoint
      scope                  = var.oidc_scope
      session_timeout        = 300
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.agent.arn
  }

  condition {
    path_pattern {
      values = ["/invocations", "/docs", "/openapi.json"]
    }
  }
}

# Listener Rule for Session Binding with OIDC authentication
resource "aws_lb_listener_rule" "session_binding" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 22

  action {
    type = "authenticate-oidc"

    authenticate_oidc {
      authorization_endpoint = var.oidc_authorization_endpoint
      client_id              = var.oidc_client_id
      client_secret          = var.oidc_client_secret
      issuer                 = var.oidc_issuer
      token_endpoint         = var.oidc_token_endpoint
      user_info_endpoint     = var.oidc_user_info_endpoint
      scope                  = var.oidc_scope
      session_timeout        = 300
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.session_binding.arn
  }

  condition {
    path_pattern {
      values = ["/oauth2/session-binding"]
    }
  }
}

# Route53 A Record
resource "aws_route53_record" "main" {
  zone_id = var.hosted_zone_id
  name    = var.subdomain
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}
