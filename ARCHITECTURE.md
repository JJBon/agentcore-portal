# Architecture Overview

## Module Structure

This Terraform module provides a complete, production-ready deployment that creates the following structure:

```
agentcore-terraform-module/
├── Root Module (4 files, ~500 lines)
│   ├── main.tf           - Module orchestration
│   ├── variables.tf      - 25+ input variables
│   ├── outputs.tf        - 10+ outputs
│   └── versions.tf       - Provider constraints
│
├── Modules (6 modules, ~2000 lines)
│   ├── vpc/              - VPC, subnets, NAT Gateway (3 files)
│   ├── storage/          - S3 buckets, KMS encryption (3 files)
│   ├── alb/              - ALB, ACM, OIDC listeners (3 files)
│   ├── identity/         - AgentCore workload identity (3 files)
│   ├── ecs/              - ECS cluster, services, IAM (3 files)
│   └── waf/              - WAF rules, rate limiting (3 files)
│
├── Examples
│   └── complete/         - Full deployment example
│       ├── main.tf                      - ECR + module invocation
│       ├── variables.tf                 - Variable definitions
│       ├── terraform.tfvars.example     - Configuration template
│       ├── deploy.sh                    - Automated deployment
│       ├── destroy.sh                   - Clean teardown
│       └── README.md                    - Deployment guide
│
└── Documentation
    ├── README.md              - Module overview
    ├── ARCHITECTURE.md        - This file
    ├── CDK_VS_TERRAFORM.md    - CDK comparison
    ├── GETTING_STARTED.md     - Step-by-step guide
    └── .gitignore             - Standard ignore patterns

Total: ~30 files, ~3,500 lines of code
```

## High-Level Architecture

```
┌─────────────┐
│   Internet  │
└──────┬──────┘
       │ HTTPS
       ▼
┌─────────────────────────────────────────────────────────────┐
│  Application Load Balancer (OIDC Auth)                      │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────────┐   │
│  │ ACM Cert     │  │ WAF Rules    │  │ Route53 Record  │   │
│  └──────────────┘  └──────────────┘  └─────────────────┘   │
└───────────────┬──────────────────────────┬──────────────────┘
                │                          │
      ┌─────────▼──────────┐    ┌─────────▼──────────────────┐
      │  Agent Service     │    │ Session Binding Service    │
      │  (ECS Fargate)     │    │ (ECS Fargate Spot)         │
      │  ┌──────────────┐  │    │  ┌──────────────────────┐  │
      │  │ Strands      │  │    │  │ OAuth Callback       │  │
      │  │ Agent        │  │    │  │ Handler              │  │
      │  └──────────────┘  │    │  └──────────────────────┘  │
      └─────────┬──────────┘    └────────────┬───────────────┘
                │                            │
                │ Private Subnets            │
                └────────────┬───────────────┘
                             │
      ┌──────────────────────┼──────────────────────┐
      │                      │                      │
      ▼                      ▼                      ▼
┌─────────────┐    ┌──────────────────┐    ┌────────────────┐
│   S3        │    │ AgentCore        │    │   Bedrock      │
│  Sessions   │    │  Identity        │    │   Claude       │
└─────────────┘    └──────────────────┘    └────────────────┘
                           │
                           ▼
                   ┌────────────────┐
                   │    GitHub      │
                   │   OAuth API    │
                   └────────────────┘
```

## Component Details

### 1. **VPC Module** (`modules/vpc`)
- **Purpose**: Network isolation and security
- **Resources**:
  - VPC with DNS support
  - 2 Public subnets (for ALB)
  - 2 Private subnets (for ECS tasks)
  - Internet Gateway
  - NAT Gateway (single for cost optimization)
  - Route tables and associations
- **Security**: ECS tasks in private subnets, no direct internet access

### 2. **Storage Module** (`modules/storage`)
- **Purpose**: Persistent storage and encryption
- **Resources**:
  - KMS key for S3 encryption (automatic rotation)
  - S3 sessions bucket (encrypted, versioned)
  - S3 access logs bucket
  - Lifecycle policies (Glacier @ 30d, Expire @ 90d)
- **Security**: All data encrypted at rest, SSL enforcement

### 3. **ALB Module** (`modules/alb`)
- **Purpose**: Load balancing and OIDC authentication
- **Resources**:
  - Security group (HTTPS/HTTP)
  - ACM certificate with DNS validation
  - Application Load Balancer
  - HTTP listener (redirects to HTTPS)
  - HTTPS listener (TLS 1.3)
  - 2 Target groups (agent, session-binding)
  - 2 Listener rules (with OIDC auth)
  - Route53 A record (alias to ALB)
- **Security**: OIDC authentication on all paths, TLS 1.3 enforced

### 4. **Identity Module** (`modules/identity`)
- **Purpose**: AgentCore workload identity management
- **Resources**:
  - KMS key for CloudWatch Logs
  - AgentCore Workload Identity
  - Log group permissions
- **Security**: Separate KMS key, automatic rotation

### 5. **ECS Module** (`modules/ecs`)
- **Purpose**: Container orchestration
- **Resources**:
  - ECS cluster with Container Insights
  - Capacity providers (FARGATE, FARGATE_SPOT)
  - 2 CloudWatch log groups (KMS encrypted)
  - Security group (minimal egress)
  - 3 IAM roles:
    - Execution role (ECR, CloudWatch, Secrets Manager)
    - Agent task role (Bedrock, S3, AgentCore Identity)
    - Session binding task role (AgentCore Identity)
  - 2 Task definitions (ARM64)
  - 2 ECS services
- **Security**: Least privilege IAM, encrypted logs, private networking

### 6. **WAF Module** (`modules/waf`)
- **Purpose**: Web application firewall
- **Resources**:
  - WAF Web ACL
  - AWS Managed Rules (Common, Known Bad Inputs)
  - Rate limiting (2000 req/5min)
  - WAF logging with PII redaction
- **Security**: Protection against common web exploits

## Data Flow

### User Request Flow
```
1. User → ALB (HTTPS)
2. ALB → Cognito (OIDC authentication)
3. ALB → ECS Agent (with x-amzn-oidc-data header)
4. Agent → AgentCore Identity (get workload token)
5. Agent → S3 (load session)
6. Agent → Bedrock (invoke Claude)
7. Agent → AgentCore Identity (get GitHub token)
   - If no token: return authorization URL
   - If token exists: use cached token
8. Agent → GitHub API (authenticated request)
9. Agent → S3 (save session)
10. Agent → User (response)
```

### OAuth 3-Legged Flow
```
1. Agent → AgentCore Identity (GetResourceOAuth2Token)
2. AgentCore Identity → Agent (authorizationUrl + sessionUri)
3. Agent → User (return authorization URL)
4. User → GitHub (click URL, authorize)
5. GitHub → AgentCore Identity (redirect with code)
6. AgentCore Identity → Session Binding Service (redirect with sessionUri)
7. Session Binding → AgentCore Identity (CompleteResourceTokenAuth)
8. AgentCore Identity → Token Vault (store OAuth token)
9. User → Agent (retry original request)
10. Agent → AgentCore Identity (GetResourceOAuth2Token)
11. AgentCore Identity → Agent (cached GitHub token)
12. Agent → GitHub API (use token)
```

## Security Architecture

### Authentication Layers
1. **User Authentication**: Cognito OIDC via ALB
2. **Service Authentication**: IAM roles for AWS services
3. **API Authentication**: AgentCore Identity for GitHub OAuth

### Encryption
- **In Transit**: TLS 1.3 (ALB), HTTPS (all API calls)
- **At Rest**:
  - S3: KMS customer-managed key
  - CloudWatch Logs: KMS customer-managed key
  - Secrets Manager: KMS default key

### Network Security
- **Public**: ALB only
- **Private**: All ECS tasks, no direct internet access
- **Egress**: Through NAT Gateway
- **Security Groups**: Minimal ports, no unnecessary access

### IAM Policies
- **Least Privilege**: Each role has only required permissions
- **Scoped Access**: S3 policies scoped to specific prefixes
- **Bedrock**: Only inference via specific profile
- **AgentCore**: Only specific workload operations

## Monitoring & Observability

### Logs
- **ALB Access Logs**: S3 bucket
- **ECS Container Logs**: CloudWatch Logs (KMS encrypted)
- **WAF Logs**: CloudWatch Logs (KMS encrypted)

### Metrics
- **Container Insights**: CPU, memory, network
- **ALB Metrics**: Request count, latency, errors
- **ECS Metrics**: Task count, CPU/memory utilization

### Alarms (not included, but recommended)
- High error rate (>5%)
- High latency (>2s p99)
- Task failures
- S3 bucket size

## Cost Optimization

### Implemented
- Single NAT Gateway (consider multi-AZ for HA)
- Fargate Spot for session binding service
- S3 lifecycle policies (Glacier, expiration)
- 7-day log retention

### Monthly Cost Estimate

Approximate monthly costs in us-east-1:
- **ECS Fargate** (2 tasks): ~$30
- **Application Load Balancer**: ~$20
- **NAT Gateway**: ~$35
- **S3, CloudWatch, KMS**: ~$10
- **Total**: ~$95/month

### Additional Recommendations
- Use Compute Savings Plans for Fargate
- Enable S3 Intelligent-Tiering
- Use CloudWatch log insights instead of exporting
- Consider Reserved Capacity for predictable workloads

## High Availability

### Current Setup
- Multi-AZ VPC
- ALB across multiple AZs
- ECS services in multiple subnets
- S3 and DynamoDB (if used) are inherently HA

### Limitations
- Single NAT Gateway (cost optimization)
- Single region deployment

### For Production HA
- Add NAT Gateway per AZ
- Multi-region deployment with Route53 failover
- Cross-region S3 replication
- ECS service auto-scaling

## Disaster Recovery

### Backup Strategy
- S3 versioning enabled
- CloudWatch Logs retention
- Terraform state (recommended: S3 backend with versioning)

### Recovery Procedures
1. **Data Loss**: Restore from S3 versions
2. **Region Failure**: Deploy to another region via Terraform
3. **Service Failure**: ECS auto-restarts tasks

## Compliance Considerations

### GDPR
- User data in S3 (per-user isolation)
- Data deletion via S3 lifecycle or manual
- Encryption at rest

### HIPAA
- KMS encryption
- VPC isolation
- Access logging
- No direct internet access for data

### SOC 2
- CloudTrail for audit logs
- Encryption in transit and at rest
- IAM least privilege
- WAF protection

## Scaling Considerations

### Horizontal Scaling
- ECS service auto-scaling (not included, recommended)
- ALB handles traffic distribution
- Multiple ECS tasks per service

### Vertical Scaling
- Adjust task CPU/memory via variables
- No downtime (rolling deployment)

### Limits
- ALB: 100 targets per target group
- ECS: 1000 tasks per cluster (soft limit)
- Fargate: Based on region and account limits

## Troubleshooting Guide

### Common Issues

#### 1. ECS Task Not Starting
- **Symptoms**: Service desired count > running count
- **Check**:
  - CloudWatch Logs for container errors
  - ECR image availability
  - IAM role permissions
  - Task definition configuration

#### 2. 502 Bad Gateway
- **Symptoms**: ALB returns 502
- **Check**:
  - Target health checks
  - Security group rules
  - Container logs
  - Network connectivity

#### 3. OAuth Flow Failing
- **Symptoms**: Authorization URL not working
- **Check**:
  - GitHub OAuth app configuration
  - AgentCore Identity provider name
  - Session binding URL configuration
  - Cognito callback URLs

#### 4. High Costs
- **Check**:
  - NAT Gateway data transfer
  - CloudWatch Logs retention
  - Unused resources
  - Fargate task sizes

## Deployment Guide

### Prerequisites

Before deploying, ensure you have:

1. **AWS Account** with appropriate IAM permissions
2. **Terraform** >= 1.5 installed
3. **AWS CLI** configured with credentials
4. **Docker** installed and running
5. **Route53 Hosted Zone** for your domain
6. **Cognito User Pool** with app client configured
7. **GitHub OAuth Provider** registered with AgentCore Identity (if using existing)

### Deployment Options

#### Option 1: Automated Deployment Script

```bash
cd examples/complete
./deploy.sh
```

The script will:
1. Check prerequisites (Terraform, AWS CLI, Docker)
2. Initialize Terraform
3. Show execution plan
4. Deploy base infrastructure
5. Guide you through Docker image building
6. Deploy ECS services
7. Configure Cognito callback URLs

#### Option 2: Manual Deployment

```bash
cd examples/complete

# Step 1: Copy example config
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# Step 2: Initialize Terraform
terraform init

# Step 3: Deploy base infrastructure (ECS will fail - no images yet)
terraform apply

# Step 4: Build and push Docker images
AWS_REGION=us-east-1
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# ECR login
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Get repository URLs
AGENT_REPO=$(terraform output -raw ecr_agent_repository_url)
SESSION_REPO=$(terraform output -raw ecr_session_binding_repository_url)

# Build and push
cd backend
docker build -t $AGENT_REPO:latest -f runtime/Dockerfile runtime/
docker push $AGENT_REPO:latest

docker build -t $SESSION_REPO:latest -f session_binding/Dockerfile session_binding/
docker push $SESSION_REPO:latest

# Step 5: Deploy ECS services (will succeed now)
cd ..
terraform apply

# Step 6: Update Cognito with callback URL
CALLBACK_URL=$(terraform output -raw cognito_callback_url)
POOL_ID="your-pool-id"  # From terraform.tfvars
CLIENT_ID="your-client-id"  # From terraform.tfvars

aws cognito-idp update-user-pool-client \
  --user-pool-id $POOL_ID \
  --client-id $CLIENT_ID \
  --callback-urls "$CALLBACK_URL" \
  --supported-identity-providers "COGNITO" \
  --allowed-o-auth-flows "code" \
  --allowed-o-auth-scopes "openid" "email" "profile" \
  --allowed-o-auth-flows-user-pool-client
```

### Testing Your Deployment

```bash
# Get agent URL
AGENT_URL=$(terraform output -raw agent_url)

# Test health check
curl -I $AGENT_URL/docs

# Open in browser
echo "Open this URL: $AGENT_URL/docs"
```

You should see a redirect to Cognito login. After authentication, you'll access the agent API.

### Cleanup

```bash
cd examples/complete
./destroy.sh
```

Or manually:

```bash
# Empty S3 buckets first
aws s3 rm s3://$(terraform output -raw s3_sessions_bucket) --recursive
aws s3 rm s3://$(terraform output -raw s3_access_logs_bucket) --recursive

# Destroy infrastructure
terraform destroy
```

## Security Features

This module implements comprehensive security controls:

- ✅ **Encryption at Rest**: All data encrypted with KMS (S3, CloudWatch Logs)
- ✅ **Encryption in Transit**: TLS 1.3 enforced on ALB, HTTPS for all API calls
- ✅ **Secrets Management**: Cognito credentials stored in AWS Secrets Manager
- ✅ **Network Isolation**: ECS tasks in private subnets with no direct internet access
- ✅ **WAF Protection**: Rate limiting and AWS Managed Rules
- ✅ **IAM Least Privilege**: Scoped permissions for each service
- ✅ **Session Isolation**: Per-user session data stored separately in S3
- ✅ **OIDC Authentication**: Cognito-based user authentication via ALB
- ✅ **Audit Logging**: CloudWatch Logs and ALB access logs
