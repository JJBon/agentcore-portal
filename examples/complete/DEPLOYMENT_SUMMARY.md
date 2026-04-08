# Deployment Summary

## Prerequisites Checklist

Before running Terraform, ensure these resources exist:

### ✅ Must Exist Before Terraform

1. **Route53 Hosted Zone**
   - Resource: Hosted Zone for your domain
   - Required: Hosted Zone ID
   - Verify: `aws route53 get-hosted-zone --id <zone-id>`

2. **Cognito User Pool & App Client**
   - Resource: Complete Cognito setup with user pool and app client
   - Required:
     - User Pool ID (e.g., `us-east-1_xxxxxx`)
     - App Client ID
     - App Client Secret
     - Cognito Domain (e.g., `your-app.auth.region.amazoncognito.com`)
     - Issuer URL (e.g., `https://cognito-idp.region.amazonaws.com/us-east-1_xxxxx`)
   - Verify: `aws cognito-idp describe-user-pool --user-pool-id <pool-id>`

3. **GitHub OAuth Provider** (optional)
   - Resource: GitHub OAuth provider registered with AgentCore Identity
   - Required only if: `create_github_provider = false` in terraform.tfvars
   - Provider name must match value in terraform.tfvars

4. **Docker Images** (for successful ECS deployment)
   - Resource: Container images for agent and session-binding
   - Required: Images pushed to ECR with `latest` tag
   - Without images: ECS tasks will fail to start (but infrastructure deploys)

### 🔧 Created by Terraform

These resources are automatically created - DO NOT create manually:

- ECR repositories (agentcore-agent, agentcore-session-binding)
- Secrets Manager secret (stores Cognito credentials)
- VPC and all networking (subnets, NAT gateway, IGW)
- Application Load Balancer with ACM certificate
- ECS Cluster, Task Definitions, Services
- S3 buckets (sessions, access logs)
- KMS keys for encryption
- IAM roles and policies
- Security groups
- CloudWatch log groups
- AgentCore Workload Identity (if enabled)

## Deployment Order

### Recommended Path (Images Exist)

1. ✓ Verify prerequisites exist
2. ✓ Configure terraform.tfvars with existing resource IDs
3. ✓ Push Docker images to ECR (can be done before or right after creating repos)
4. ✓ Run `terraform apply`
5. ✓ Update Cognito callback URLs
6. ✓ Test deployment

### Alternative Path (No Images Yet)

1. ✓ Verify prerequisites exist
2. ✓ Configure terraform.tfvars with existing resource IDs
3. ✓ Run `terraform apply` (ECS services will fail - expected)
4. ✓ Build and push Docker images to ECR
5. ✓ Run `terraform apply` again (ECS services start successfully)
6. ✓ Update Cognito callback URLs
7. ✓ Test deployment

## Post-Deployment Configuration

### Update Cognito Callback URL

After Terraform creates the ALB, you must update Cognito:

```bash
CALLBACK_URL=$(terraform output -raw cognito_callback_url)
# Returns: https://agent-3lo.yourdomain.com/oauth2/idpresponse

aws cognito-idp update-user-pool-client \
  --user-pool-id <your-pool-id> \
  --client-id <your-client-id> \
  --callback-urls "$CALLBACK_URL" \
  --supported-identity-providers "COGNITO" \
  --allowed-o-auth-flows "code" \
  --allowed-o-auth-scopes "openid" "email" "profile" \
  --allowed-o-auth-flows-user-pool-client
```

This step is REQUIRED for OAuth authentication to work.

## What Each Resource Does

### Resources That Must Pre-Exist

| Resource | Purpose | Why Pre-Exist? |
|----------|---------|----------------|
| Route53 Hosted Zone | DNS management for your domain | Domain ownership verification; ACM certificate validation requires existing zone |
| Cognito User Pool | User authentication and management | Application-level resource that defines your auth strategy; often shared across multiple apps |
| Cognito App Client | OAuth 2.0 client credentials | Defines OAuth scopes, flows, and client secrets; may be created via CDK or other tools |
| GitHub OAuth Provider | GitHub authentication for AgentCore | Shared identity provider that can be used by multiple workloads |

### Resources Created by Terraform

| Resource | Purpose |
|----------|---------|
| ECR Repositories | Store Docker images for agent and session-binding |
| Secrets Manager Secret | Securely store Cognito credentials (encrypted with KMS) |
| VPC | Network isolation for ECS tasks |
| ALB | Load balancing, SSL termination, and OAuth2 proxy |
| ACM Certificate | SSL/TLS certificate for HTTPS (auto-validated via Route53) |
| ECS Cluster/Services | Run containerized agent and session-binding services |
| S3 Buckets | Store session data and ALB access logs |
| KMS Keys | Encrypt data at rest (S3, Secrets Manager, CloudWatch) |
| IAM Roles | Grant permissions to ECS tasks (Bedrock, S3, Secrets Manager) |
| Security Groups | Control network access to ALB and ECS tasks |

## Common Issues

### Issue: ECS Tasks Won't Start

**Symptom**: `runningCount: 0`, tasks immediately stop

**Cause**: Docker images don't exist in ECR or have wrong tag

**Solution**:
```bash
# Verify images exist
aws ecr describe-images --repository-name agentcore-agent --region us-east-1

# If missing, push images
docker build -t <ecr-repo-url>:latest /path/to/code
docker push <ecr-repo-url>:latest

# Re-apply terraform
terraform apply -auto-approve
```

### Issue: Cognito OAuth Fails

**Symptom**: "redirect_uri_mismatch" error

**Cause**: Callback URL not configured in Cognito

**Solution**:
```bash
# Get callback URL
terraform output cognito_callback_url

# Update Cognito (see command above)
```

### Issue: Terraform "Resource Already Exists"

**Symptom**: ECR repos or other resources already exist

**Cause**: Resources created from previous deployment

**Solution**:
```bash
# Option 1: Import into state
terraform import aws_ecr_repository.agent agentcore-agent

# Option 2: Delete and recreate
aws ecr delete-repository --repository-name agentcore-agent --force
terraform apply
```

### Issue: Windows Line Endings

**Symptom**: `$'\r': command not found` when running deploy.sh

**Cause**: Windows CRLF line endings

**Solution**:
```bash
sed -i 's/\r$//' deploy.sh
```

## Verification Commands

After deployment, verify everything is working:

```bash
# Check ECS services
aws ecs describe-services \
  --cluster agentcore-prod-cluster \
  --services agentcore-prod-agent agentcore-prod-session-binding \
  --region us-east-1 | \
  jq '.services[] | {name: .serviceName, status, runningCount, desiredCount}'

# Test agent endpoint (should return 302 to Cognito)
curl -I https://agent-3lo.yourdomain.com/docs

# Check CloudWatch logs
aws logs tail /ecs/agentcore-prod-agent --follow --region us-east-1
```

## Cost Estimate

Monthly costs in us-east-1:

- ECS Fargate (2 tasks, 512 CPU, 1GB memory): ~$30
- Application Load Balancer: ~$20
- NAT Gateway: ~$35
- S3, CloudWatch, KMS: ~$10
- **Total**: ~$95/month

## Cleanup

To destroy all resources:

```bash
# Empty S3 buckets first (required for deletion)
aws s3 rm s3://sessions-<account-id>-prod --recursive
aws s3 rm s3://access-logs-<account-id>-prod --recursive

# Destroy infrastructure
terraform destroy

# Optionally delete Docker images
aws ecr delete-repository --repository-name agentcore-agent --force
aws ecr delete-repository --repository-name agentcore-session-binding --force
```

**Note**: Terraform will not delete:
- Route53 Hosted Zone (pre-existing)
- Cognito User Pool & App Client (pre-existing)
- GitHub OAuth Provider (pre-existing)

These resources must be cleaned up manually if no longer needed.
