terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.39.0"
    }
  }

  # Uncomment for remote state
  # backend "s3" {
  #   bucket = "your-terraform-state-bucket"
  #   key    = "agentcore-3lo/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

provider "aws" {
  region = var.aws_region
}

# Create ECR repositories for Docker images
resource "aws_ecr_repository" "agent" {
  name                 = "${var.project_name}-agent"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_repository" "session_binding" {
  name                 = "${var.project_name}-session-binding"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

# ECR lifecycle policies
resource "aws_ecr_lifecycle_policy" "agent" {
  repository = aws_ecr_repository.agent.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus     = "any"
        countType     = "imageCountMoreThan"
        countNumber   = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}

resource "aws_ecr_lifecycle_policy" "session_binding" {
  repository = aws_ecr_repository.session_binding.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus     = "any"
        countType     = "imageCountMoreThan"
        countNumber   = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}

# AgentCore 3LO OAuth Module
module "agentcore_3lo" {
  source = "../.."

  # Project Configuration
  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region

  # DNS Configuration
  domain_name      = var.domain_name
  hosted_zone_id   = var.hosted_zone_id
  agent_subdomain  = var.agent_subdomain

  # Cognito OIDC Configuration
  cognito_user_pool_id   = var.cognito_user_pool_id
  cognito_client_id      = var.cognito_client_id
  cognito_client_secret  = var.cognito_client_secret
  cognito_domain         = var.cognito_domain
  cognito_issuer         = var.cognito_issuer

  # AgentCore Identity
  workload_identity_name   = var.workload_identity_name
  create_workload_identity = var.create_workload_identity
  github_provider_name     = var.github_provider_name
  create_github_provider   = var.create_github_provider
  github_client_id         = var.github_client_id
  github_client_secret     = var.github_client_secret

  # Bedrock
  inference_profile_id = var.inference_profile_id

  # Docker Images (use ECR repositories)
  agent_image           = "${aws_ecr_repository.agent.repository_url}:latest"
  session_binding_image = "${aws_ecr_repository.session_binding.repository_url}:latest"

  # Optional Features
  enable_waf = var.enable_waf

  # Optional: Customize resources
  agent_task_cpu                  = 512
  agent_task_memory               = 1024
  session_binding_task_cpu        = 256
  session_binding_task_memory     = 512
  log_retention_days              = 7
  session_lifecycle_glacier_days  = 30
  session_lifecycle_expire_days   = 90

  tags = {
    Owner       = "DevOps"
    CostCenter  = "Engineering"
    Compliance  = "HIPAA"
  }
}

# Outputs
output "agent_url" {
  description = "Agent URL"
  value       = module.agentcore_3lo.agent_url
}

output "agent_docs_url" {
  description = "Agent docs URL"
  value       = module.agentcore_3lo.agent_docs_url
}

output "cognito_callback_url" {
  description = "Add this URL to Cognito app client callback URLs"
  value       = module.agentcore_3lo.cognito_callback_url
}

output "ecr_agent_repository_url" {
  description = "ECR repository URL for agent image"
  value       = aws_ecr_repository.agent.repository_url
}

output "ecr_session_binding_repository_url" {
  description = "ECR repository URL for session binding image"
  value       = aws_ecr_repository.session_binding.repository_url
}

output "docker_login_command" {
  description = "Command to login to ECR"
  value       = "aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${aws_ecr_repository.agent.repository_url}"
}
