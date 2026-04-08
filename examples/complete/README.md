# Complete Example Deployment

This example shows how to deploy the full AgentCore 3LO OAuth infrastructure using Terraform.

## Prerequisites

### Required Before Running Terraform

These resources **must exist** before running `terraform apply`:

1. **AWS Account** with appropriate IAM permissions
2. **Terraform** >= 1.5 installed
3. **AWS CLI** configured with credentials
4. **Route53 Hosted Zone** for your domain
   - You need the Hosted Zone ID
   - Domain must be registered and DNS configured

5. **Cognito User Pool & App Client** already created
   - User Pool ID (e.g., `us-east-1_xxxx`)
   - App Client ID
   - App Client Secret
   - Cognito Domain (e.g., `your-app.auth.us-east-1.amazoncognito.com`)
   - Cognito Issuer URL (e.g., `https://cognito-idp.us-east-1.amazonaws.com/us-east-1_xxxx`)

6. **GitHub OAuth Provider** (if using existing)
   - Only required if setting `create_github_provider = false`
   - Provider must be registered with AgentCore Identity

### Required for Complete Deployment

7. **Docker** installed and running
   - Needed to build and push container images
   - Images must be pushed to ECR before ECS services can run

## What Terraform Creates vs What Must Exist

**Terraform CREATES these resources** (you don't need to create them manually):
- ✓ ECR repositories (agentcore-agent, agentcore-session-binding)
- ✓ Secrets Manager secret (stores Cognito credentials from tfvars)
- ✓ VPC, Subnets, NAT Gateway, Internet Gateway
- ✓ Application Load Balancer
- ✓ ACM SSL Certificate (auto-validated via Route53)
- ✓ ECS Cluster, Task Definitions, Services
- ✓ S3 Buckets (sessions, access logs)
- ✓ KMS Keys (for encryption)
- ✓ IAM Roles and Policies
- ✓ Security Groups
- ✓ CloudWatch Log Groups
- ✓ AgentCore Workload Identity (if create_workload_identity = true)

**You MUST create these BEFORE running Terraform**:
- ⚠️ Route53 Hosted Zone (referenced by hosted_zone_id)
- ⚠️ Cognito User Pool with App Client (complete with credentials)
- ⚠️ GitHub OAuth Provider (if create_github_provider = false)
- ⚠️ Docker images pushed to ECR (for ECS services to start successfully)

**Key Point**: The Secrets Manager secret is created by Terraform, but it stores the Cognito credentials that you provide in `terraform.tfvars`. The Cognito resources themselves must already exist.

## Step-by-Step Deployment

### 1. Verify Prerequisites Exist

Before starting, ensure you have:

```bash
# Verify Route53 hosted zone exists
aws route53 get-hosted-zone --id <your-hosted-zone-id>

# Verify Cognito user pool exists
aws cognito-idp describe-user-pool --user-pool-id <your-pool-id>

# Verify Cognito app client exists
aws cognito-idp describe-user-pool-client \
  --user-pool-id <your-pool-id> \
  --client-id <your-client-id>
```

### 2. Configure Variables

Copy the example tfvars file and customize with your existing resources:

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

**Important**: Update these values with your existing resources:
- `hosted_zone_id` - Your Route53 hosted zone ID
- `cognito_user_pool_id` - Your Cognito user pool ID
- `cognito_client_id` - Your Cognito app client ID
- `cognito_client_secret` - Your Cognito app client secret
- `cognito_domain` - Your Cognito domain
- `cognito_issuer` - Your Cognito issuer URL
- `github_provider_name` - Your GitHub OAuth provider name (if using existing)

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Plan the Deployment

```bash
terraform plan -out=tfplan
```

Review the plan carefully. It should create ~69 resources including:
- ECR repositories (agentcore-agent, agentcore-session-binding)
- VPC with public/private subnets
- NAT Gateway and Internet Gateway
- Application Load Balancer with ACM certificate
- ECS Cluster, Task Definitions, and Services
- S3 buckets (sessions, access logs)
- Secrets Manager secret (stores Cognito credentials)
- KMS keys for encryption
- IAM roles and policies
- CloudWatch log groups

### 5. Option A: Deploy Everything at Once (Recommended if images exist)

If you already have Docker images built and pushed to other ECR repositories:

```bash
# Push images to the ECR repos before applying
# (See step 6 for image build/push commands)

# Then apply
terraform apply tfplan
```

### 5. Option B: Deploy Infrastructure First, Images Later

If you don't have images yet, deploy infrastructure first (ECS services will fail initially):

```bash
terraform apply tfplan
```

**Expected behavior**: Terraform will create all infrastructure, but ECS tasks will fail to start because Docker images don't exist yet. This is normal.

### 6. Build and Push Docker Images

After ECR repositories are created, build and push your Docker images:

```bash
# Get ECR repository URLs
AGENT_REPO=$(terraform output -raw ecr_agent_repository_url)
SESSION_REPO=$(terraform output -raw ecr_session_binding_repository_url)
AWS_REGION=$(terraform output -json | jq -r '.aws_region.value // "us-east-1"')

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin ${AGENT_REPO%%/*}

# Build and push agent image
docker build -t $AGENT_REPO:latest /path/to/agent/code
docker push $AGENT_REPO:latest

# Build and push session binding image
docker build -t $SESSION_REPO:latest /path/to/session-binding/code
docker push $SESSION_REPO:latest
```

**Where to find the code**:
- Reference CDK implementation: `../../01-tutorials/03-AgentCore-identity/07-Outbound_Auth_3LO_ECS_Fargate`
- Or provide your own agent and session binding implementations

### 7. Deploy/Update ECS Services (if using Option B)

If you deployed infrastructure without images (Option B), now apply again to start ECS services:

```bash
terraform apply -auto-approve
```

This will recreate the ECS tasks with the newly available Docker images.

### 8. Update Cognito Callback URLs

After deployment, add the ALB callback URL to your Cognito app client:

```bash
# Get configuration from Terraform outputs
CALLBACK_URL=$(terraform output -raw cognito_callback_url)
POOL_ID=$(terraform show -json | jq -r '.values.root_module.child_modules[0].resources[] | select(.address=="module.agentcore_3lo.var.cognito_user_pool_id") // empty')

# Use the values from your terraform.tfvars
POOL_ID="us-east-1_1jPxiDt0C"  # Replace with your pool ID
CLIENT_ID="3d7iu3nkpd2m45jcfa88r5eauf"  # Replace with your client ID

# Update Cognito app client
aws cognito-idp update-user-pool-client \
  --user-pool-id $POOL_ID \
  --client-id $CLIENT_ID \
  --callback-urls "$CALLBACK_URL" \
  --supported-identity-providers "COGNITO" \
  --allowed-o-auth-flows "code" \
  --allowed-o-auth-scopes "openid" "email" "profile" \
  --allowed-o-auth-flows-user-pool-client

# Verify the update
aws cognito-idp describe-user-pool-client \
  --user-pool-id $POOL_ID \
  --client-id $CLIENT_ID \
  --query 'UserPoolClient.CallbackURLs'
```

### 9. Verify Deployment

Check that services are running:

```bash
# Check ECS service status
aws ecs describe-services \
  --cluster agentcore-prod-cluster \
  --services agentcore-prod-agent agentcore-prod-session-binding \
  --region us-east-1 | \
  jq '.services[] | {name: .serviceName, status: .status, runningCount, desiredCount}'

# Check task health
aws ecs list-tasks \
  --cluster agentcore-prod-cluster \
  --service-name agentcore-prod-agent \
  --region us-east-1
```

### 10. Test the Agent

Access your agent:

```bash
# Get the agent URL
AGENT_URL=$(terraform output -raw agent_url)
echo "Agent URL: $AGENT_URL"
echo "Agent Docs: $AGENT_URL/docs"

# Test the endpoint (should redirect to Cognito login)
curl -I $AGENT_URL/docs

# Open in browser
open $AGENT_URL/docs
```

You should see a redirect (HTTP 302) to Cognito authentication.

## Outputs

After successful deployment, you'll have:

```bash
terraform output
```

Key outputs:
- `agent_url` - HTTPS URL to access the agent
- `agent_docs_url` - OpenAPI documentation
- `cognito_callback_url` - Add to Cognito
- `ecr_agent_repository_url` - ECR repo for agent images
- `ecr_session_binding_repository_url` - ECR repo for session binding images

## Cost Estimation

Monthly costs (us-east-1):
- **ECS Fargate** (2 tasks): ~$30
- **ALB**: ~$20
- **NAT Gateway**: ~$35
- **S3, CloudWatch, KMS**: ~$10
- **Total**: ~$95/month

## Cleanup

To destroy all resources:

```bash
# Empty S3 buckets first (they have deletion protection)
aws s3 rm s3://$(terraform output -raw s3_sessions_bucket) --recursive
aws s3 rm s3://$(terraform output -raw s3_access_logs_bucket) --recursive

# Destroy infrastructure
terraform destroy
```

## Troubleshooting

### ECS Task Failed to Start

**Symptoms**: `runningCount: 0`, tasks keep stopping

**Causes**:
1. Docker images don't exist or have wrong tag
2. IAM permissions issues
3. Application errors

**Debug**:
```bash
# Check CloudWatch Logs
aws logs tail /ecs/agentcore-prod-agent --follow --region us-east-1

# Check task stopped reason
aws ecs describe-tasks \
  --cluster agentcore-prod-cluster \
  --tasks $(aws ecs list-tasks --cluster agentcore-prod-cluster --service agentcore-prod-agent --desired-status STOPPED --region us-east-1 | jq -r '.taskArns[0]') \
  --region us-east-1 | jq '.tasks[0].stoppedReason'

# Verify images exist
aws ecr describe-images --repository-name agentcore-agent --region us-east-1
```

### ALB Returns 502/503

**Symptoms**: ALB returns 502 Bad Gateway or 503 Service Unavailable

**Causes**:
1. ECS tasks not running
2. Health checks failing
3. Security group blocking traffic

**Debug**:
```bash
# Check ECS service status
aws ecs describe-services \
  --cluster agentcore-prod-cluster \
  --services agentcore-prod-agent \
  --region us-east-1 | jq '.services[0] | {status, runningCount, desiredCount, healthCheck}'

# Check target group health
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn 2>/dev/null || echo "get-from-console") \
  --region us-east-1
```

### Cognito Authentication Failed

**Symptoms**:
- "redirect_uri_mismatch" error
- OAuth flow fails

**Causes**: Callback URL not configured in Cognito

**Debug**:
```bash
# Verify callback URLs
aws cognito-idp describe-user-pool-client \
  --user-pool-id <pool-id> \
  --client-id <client-id> \
  --query 'UserPoolClient.CallbackURLs' \
  --region us-east-1

# Compare with Terraform output
terraform output cognito_callback_url
```

### Terraform Apply Fails

**Common errors**:

1. **"Resource already exists"**:
   - Likely ECR repos or other resources exist from previous run
   - Either delete them or import into Terraform state

2. **"InvalidParameterException: Hosted Zone not found"**:
   - Verify `hosted_zone_id` in terraform.tfvars is correct
   - Run: `aws route53 list-hosted-zones`

3. **"UserPoolId not found"**:
   - Verify Cognito user pool exists
   - Run: `aws cognito-idp describe-user-pool --user-pool-id <pool-id>`

4. **Certificate validation timeout**:
   - DNS may not be properly configured
   - Check Route53 records for domain validation

### Windows Line Ending Issues

If you see errors like `$'\r': command not found`:

```bash
# Convert line endings
sed -i 's/\r$//' deploy.sh
# Or use dos2unix if available
dos2unix deploy.sh
```

## Security Notes

- All secrets are stored in Secrets Manager
- All data encrypted with KMS
- ECS tasks run in private subnets
- WAF provides basic protection
- Consider adding:
  - AWS Shield for DDoS protection
  - GuardDuty for threat detection
  - AWS Config for compliance
  - VPC Flow Logs for network monitoring
