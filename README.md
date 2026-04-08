# AgentCore 3-Legged OAuth Terraform Module

This Terraform module deploys an AI agent on Amazon ECS Fargate with:
- **Amazon Bedrock AgentCore Identity** for 3-legged OAuth flow
- **Application Load Balancer** with OIDC authentication (Cognito)
- **ECS Fargate** services (Agent + Session Binding)
- **GitHub OAuth** integration for secure API access
- **Full encryption** with KMS
- **VPC** with public/private subnets

## Architecture

```
User → ALB (OIDC/Cognito) → ECS Fargate (Agent) → AgentCore Identity → GitHub
                                    ↓
                               S3 Sessions
```

## Prerequisites

- Terraform >= 1.5
- AWS CLI configured
- Docker installed (for building images)
- Amazon Route 53 hosted zone
- Cognito User Pool with app client
- GitHub OAuth App registered with AgentCore Identity

## Quick Start

```hcl
module "agentcore_3lo" {
  source = "./agentcore-terraform-module"

  # Project
  project_name = "my-agent"
  environment  = "prod"
  aws_region   = "us-east-1"

  # DNS
  domain_name      = "example.com"
  hosted_zone_id   = "Z1234567890ABC"
  agent_subdomain  = "agent"

  # Cognito OIDC
  cognito_user_pool_id     = "us-east-1_ABC123"
  cognito_client_id        = "your-client-id"
  cognito_client_secret    = "your-client-secret"
  cognito_domain           = "your-app.auth.us-east-1.amazoncognito.com"
  cognito_issuer           = "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_ABC123"

  # AgentCore Identity
  github_provider_name = "github-oauth-client-xyz"

  # Bedrock
  inference_profile_id = "us.anthropic.claude-sonnet-4-20250514-v1:0"
}
```

## Module Structure

```
.
├── main.tf                 # Main module entry point
├── variables.tf            # Input variables
├── outputs.tf              # Output values
├── versions.tf             # Provider versions
├── modules/
│   ├── vpc/               # VPC, subnets, NAT gateway
│   ├── alb/               # Application Load Balancer, listeners
│   ├── ecs/               # ECS cluster, services, task definitions
│   ├── identity/          # AgentCore Identity workload
│   ├── storage/           # S3 buckets, KMS keys
│   └── waf/               # AWS WAF rules
└── examples/
    └── complete/          # Complete example deployment
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_name | Project name | string | - | yes |
| environment | Environment (dev/staging/prod) | string | - | yes |
| aws_region | AWS region | string | - | yes |
| domain_name | Root domain name | string | - | yes |
| hosted_zone_id | Route53 hosted zone ID | string | - | yes |
| agent_subdomain | Subdomain for agent | string | `"agent-3lo"` | no |
| cognito_user_pool_id | Cognito User Pool ID | string | - | yes |
| cognito_client_id | Cognito App Client ID | string | - | yes |
| cognito_client_secret | Cognito App Client Secret | string | - | yes |
| github_provider_name | AgentCore Identity GitHub provider name | string | - | yes |
| inference_profile_id | Bedrock inference profile ID | string | - | yes |

## Outputs

| Name | Description |
|------|-------------|
| agent_url | HTTPS URL to access the agent |
| alb_dns_name | ALB DNS name |
| s3_sessions_bucket | S3 bucket for session storage |
| workload_identity_name | AgentCore Identity workload name |
| ecs_cluster_name | ECS cluster name |

## Features

- ✅ **3-Legged OAuth Flow** - Secure user-delegated GitHub access
- ✅ **OIDC Authentication** - Cognito-based user authentication
- ✅ **Session Management** - S3-backed conversation persistence
- ✅ **Full Encryption** - KMS encryption for logs, S3, and secrets
- ✅ **High Availability** - Multi-AZ deployment with ALB
- ✅ **WAF Protection** - Basic security rules
- ✅ **HTTPS Only** - ACM certificate with automatic validation
- ✅ **Private Networking** - ECS tasks in private subnets with NAT

## Deployment Steps

1. **Configure Cognito** (see Prerequisites)
2. **Register GitHub OAuth App** with AgentCore Identity
3. **Update variables** in `terraform.tfvars`
4. **Build and push Docker images** to ECR
5. **Deploy infrastructure**:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```
6. **Update Cognito callback URLs** with ALB URL
7. **Test the agent** at the output URL

## Cost Estimation

Monthly costs (approximate):
- **ECS Fargate** (2 tasks, 0.5 vCPU, 1GB RAM): ~$30
- **ALB**: ~$20
- **NAT Gateway**: ~$35
- **S3, CloudWatch, KMS**: ~$10
- **Total**: ~$95/month

## Security Considerations

- All data encrypted at rest (KMS)
- All data encrypted in transit (TLS 1.2+)
- Secrets stored in Secrets Manager
- ECS tasks in private subnets
- WAF rules for basic protection
- IAM least-privilege policies
- Session isolation per user

## License

MIT-0
