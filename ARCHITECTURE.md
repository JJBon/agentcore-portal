# Architecture Overview

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
