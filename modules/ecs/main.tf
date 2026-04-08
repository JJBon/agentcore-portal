# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ECS Security Group
resource "aws_security_group" "ecs" {
  name        = "${var.project_name}-${var.environment}-ecs-sg"
  description = "ECS service security group"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow from ALB to services"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }

  egress {
    description = "Allow HTTPS for AWS services and external APIs"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow DNS resolution"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-ecs-sg"
    }
  )
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-${var.environment}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-cluster"
    }
  )
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1
  }
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "agent" {
  name              = "/ecs/${var.project_name}-${var.environment}/agent"
  retention_in_days = 7
  kms_key_id        = var.kms_key_arn

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-agent-logs"
    }
  )
}

resource "aws_cloudwatch_log_group" "session_binding" {
  name              = "/ecs/${var.project_name}-${var.environment}/session-binding"
  retention_in_days = 7
  kms_key_id        = var.kms_key_arn

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-session-binding-logs"
    }
  )
}

# IAM Roles - Execution Role (common for both services)
resource "aws_iam_role" "execution" {
  name = "${var.project_name}-${var.environment}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-ecs-execution-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "execution_kms" {
  name = "kms-decrypt"
  role = aws_iam_role.execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = var.kms_key_arn
      }
    ]
  })
}

# IAM Role - Agent Task Role
resource "aws_iam_role" "agent_task" {
  name = "${var.project_name}-${var.environment}-agent-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-agent-task-role"
    }
  )
}

# Agent Task Role - Bedrock Policy
resource "aws_iam_role_policy" "agent_bedrock" {
  name = "bedrock-policy"
  role = aws_iam_role.agent_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowBedrockInvokeViaInferenceProfile"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = [
          "arn:aws:bedrock:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:inference-profile/${var.inference_profile_id}"
        ]
      },
      {
        Sid    = "AllowFoundationModelViaInferenceProfile"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = [
          "arn:aws:bedrock:*::foundation-model/*"
        ]
        Condition = {
          StringLike = {
            "bedrock:InferenceProfileArn" = "arn:aws:bedrock:*:${data.aws_caller_identity.current.account_id}:inference-profile/*"
          }
        }
      }
    ]
  })
}

# Agent Task Role - AgentCore Workload Policy
resource "aws_iam_role_policy" "agent_agentcore" {
  name = "agentcore-workload-policy"
  role = aws_iam_role.agent_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowAgentCoreWorkloadAccess"
        Effect = "Allow"
        Action = [
          "bedrock-agentcore:GetWorkloadAccessTokenForUserId",
          "bedrock-agentcore:GetResourceOAuth2Token"
        ]
        Resource = [
          "arn:aws:bedrock-agentcore:${var.identity_aws_region}:${data.aws_caller_identity.current.account_id}:workload-identity-directory/default",
          "arn:aws:bedrock-agentcore:${var.identity_aws_region}:${data.aws_caller_identity.current.account_id}:workload-identity-directory/default/workload-identity/${var.workload_identity_name}",
          "arn:aws:bedrock-agentcore:${var.identity_aws_region}:${data.aws_caller_identity.current.account_id}:token-vault/default/oauth2credentialprovider/${var.github_provider_name}",
          "arn:aws:bedrock-agentcore:${var.identity_aws_region}:${data.aws_caller_identity.current.account_id}:token-vault/default"
        ]
      }
    ]
  })
}

# Agent Task Role - Secrets Manager Policy
resource "aws_iam_role_policy" "agent_secrets" {
  name = "secrets-manager-policy"
  role = aws_iam_role.agent_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSecretsManagerAgentCoreOAuth"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          "arn:aws:secretsmanager:${var.identity_aws_region}:${data.aws_caller_identity.current.account_id}:secret:bedrock-agentcore-identity!default/oauth2/${var.github_provider_name}*"
        ]
      }
    ]
  })
}

# Agent Task Role - S3 Policy
resource "aws_iam_role_policy" "agent_s3" {
  name = "s3-policy"
  role = aws_iam_role.agent_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.sessions_bucket_arn,
          "${var.sessions_bucket_arn}/*"
        ]
      }
    ]
  })
}

# Agent Task Role - KMS Policy for S3
resource "aws_iam_role_policy" "agent_kms_s3" {
  name = "kms-s3-policy"
  role = aws_iam_role.agent_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = var.sessions_kms_key_arn
      }
    ]
  })
}

# IAM Role - Session Binding Task Role
resource "aws_iam_role" "session_binding_task" {
  name = "${var.project_name}-${var.environment}-session-binding-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-session-binding-task-role"
    }
  )
}

# Session Binding Task Role - AgentCore Policy
resource "aws_iam_role_policy" "session_binding_agentcore" {
  name = "agentcore-policy"
  role = aws_iam_role.session_binding_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCompleteResourceTokenAuth"
        Effect = "Allow"
        Action = [
          "bedrock-agentcore:CompleteResourceTokenAuth"
        ]
        Resource = [
          "arn:aws:bedrock-agentcore:${var.identity_aws_region}:${data.aws_caller_identity.current.account_id}:workload-identity-directory/default",
          "arn:aws:bedrock-agentcore:${var.identity_aws_region}:${data.aws_caller_identity.current.account_id}:workload-identity-directory/default/workload-identity/${var.workload_identity_name}",
          "arn:aws:bedrock-agentcore:${var.identity_aws_region}:${data.aws_caller_identity.current.account_id}:token-vault/default",
          "arn:aws:bedrock-agentcore:${var.identity_aws_region}:${data.aws_caller_identity.current.account_id}:token-vault/default/oauth2credentialprovider/${var.github_provider_name}"
        ]
      }
    ]
  })
}

# Session Binding Task Role - Secrets Manager Policy
resource "aws_iam_role_policy" "session_binding_secrets" {
  name = "secrets-manager-policy"
  role = aws_iam_role.session_binding_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSecretsManagerAccess"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          "arn:aws:secretsmanager:${var.identity_aws_region}:${data.aws_caller_identity.current.account_id}:secret:bedrock-agentcore-identity!default/oauth2/${var.github_provider_name}*"
        ]
      }
    ]
  })
}

# Session Binding Task Role - KMS Policy
resource "aws_iam_role_policy" "session_binding_kms" {
  name = "kms-policy"
  role = aws_iam_role.session_binding_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = var.kms_key_arn
      }
    ]
  })
}

# Agent Task Definition
resource "aws_ecs_task_definition" "agent" {
  family                   = "${var.project_name}-${var.environment}-agent"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.agent_cpu
  memory                   = var.agent_memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.agent_task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([
    {
      name  = "agent"
      image = var.agent_image

      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "WORKLOAD_IDENTITY_NAME"
          value = var.workload_identity_name
        },
        {
          name  = "AWS_REGION"
          value = data.aws_region.current.name
        },
        {
          name  = "IDENTITY_AWS_REGION"
          value = var.identity_aws_region
        },
        {
          name  = "ENVIRONMENT"
          value = var.environment
        },
        {
          name  = "S3_BUCKET_NAME"
          value = var.sessions_bucket_name
        },
        {
          name  = "SESSION_BINDING_URL"
          value = var.session_binding_url
        },
        {
          name  = "INFERENCE_PROFILE_ID"
          value = var.inference_profile_id
        },
        {
          name  = "GITHUB_PROVIDER_NAME"
          value = var.github_provider_name
        },
        {
          name  = "GITHUB_API_BASE"
          value = var.github_api_base
        }
      ]

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8080/ping || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.agent.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "agent"
        }
      }
    }
  ])

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-agent-task"
    }
  )
}

# Session Binding Task Definition
resource "aws_ecs_task_definition" "session_binding" {
  family                   = "${var.project_name}-${var.environment}-session-binding"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.session_binding_cpu
  memory                   = var.session_binding_memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.session_binding_task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([
    {
      name  = "session-binding"
      image = var.session_binding_image

      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "WORKLOAD_IDENTITY_NAME"
          value = var.workload_identity_name
        },
        {
          name  = "AWS_REGION"
          value = data.aws_region.current.name
        },
        {
          name  = "IDENTITY_AWS_REGION"
          value = var.identity_aws_region
        },
        {
          name  = "ENVIRONMENT"
          value = var.environment
        },
        {
          name  = "S3_BUCKET_NAME"
          value = var.sessions_bucket_name
        },
        {
          name  = "SESSION_BINDING_URL"
          value = var.session_binding_url
        },
        {
          name  = "INFERENCE_PROFILE_ID"
          value = var.inference_profile_id
        },
        {
          name  = "GITHUB_PROVIDER_NAME"
          value = var.github_provider_name
        },
        {
          name  = "GITHUB_API_BASE"
          value = var.github_api_base
        }
      ]

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8080/ping || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.session_binding.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "session-binding"
        }
      }
    }
  ])

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-session-binding-task"
    }
  )
}

# Agent ECS Service
resource "aws_ecs_service" "agent" {
  name            = "${var.project_name}-${var.environment}-agent"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.agent.arn
  desired_count   = var.agent_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.agent_target_group_arn
    container_name   = "agent"
    container_port   = 8080
  }

  depends_on = [
    aws_iam_role_policy.agent_bedrock,
    aws_iam_role_policy.agent_agentcore,
    aws_iam_role_policy.agent_secrets,
    aws_iam_role_policy.agent_s3
  ]

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-agent-service"
    }
  )
}

# Session Binding ECS Service
resource "aws_ecs_service" "session_binding" {
  name            = "${var.project_name}-${var.environment}-session-binding"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.session_binding.arn
  desired_count   = var.session_binding_desired_count

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
    base              = 1
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.session_binding_target_group_arn
    container_name   = "session-binding"
    container_port   = 8080
  }

  depends_on = [
    aws_iam_role_policy.session_binding_agentcore,
    aws_iam_role_policy.session_binding_secrets,
    aws_iam_role_policy.session_binding_kms
  ]

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-session-binding-service"
    }
  )
}
