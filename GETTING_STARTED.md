# Getting Started with AgentCore 3LO Terraform Module

This guide will help you deploy the AgentCore 3-Legged OAuth infrastructure using Terraform.

## Prerequisites Checklist

Before you begin, ensure you have:

- [ ] AWS Account with appropriate permissions
- [ ] Terraform >= 1.5 installed ([install guide](https://developer.hashicorp.com/terraform/downloads))
- [ ] AWS CLI configured with credentials ([install guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html))
- [ ] Docker installed and running ([install guide](https://docs.docker.com/get-docker/))
- [ ] Route53 hosted zone for your domain
- [ ] Cognito User Pool with app client configured
- [ ] GitHub OAuth App registered

## Quick Start (5 Steps)

### Step 1: Clone and Configure

```bash
cd agentcore-terraform-module/examples/complete
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

### Step 2: Initialize Terraform

```bash
terraform init
```

### Step 3: Deploy Base Infrastructure

```bash
terraform apply
```

This creates ECR, VPC, S3, IAM, etc. ECS services will fail (no images yet).

### Step 4: Build and Push Docker Images

```bash
# Get ECR login
AWS_REGION=us-east-1
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Copy agent code from CDK example
cp -r ../../../01-tutorials/03-AgentCore-identity/07-Outbound_Auth_3LO_ECS_Fargate/backend .

# Build and push images
AGENT_REPO=$(terraform output -raw ecr_agent_repository_url)
SESSION_REPO=$(terraform output -raw ecr_session_binding_repository_url)

docker build -t $AGENT_REPO:latest -f ../../Dockerfile.agent .
docker push $AGENT_REPO:latest

docker build -t $SESSION_REPO:latest -f ../../Dockerfile.session-binding .
docker push $SESSION_REPO:latest
```

### Step 5: Deploy ECS Services

```bash
terraform apply
```

Now ECS services will start successfully!

### Step 6: Configure Cognito

```bash
# Add callback URL to Cognito
CALLBACK_URL=$(terraform output -raw cognito_callback_url)

aws cognito-idp update-user-pool-client \
  --user-pool-id <your-pool-id> \
  --client-id <your-client-id> \
  --callback-urls "$CALLBACK_URL" \
  --supported-identity-providers "COGNITO" \
  --allowed-o-auth-flows "code" \
  --allowed-o-auth-scopes "openid" "email" "profile" \
  --allowed-o-auth-flows-user-pool-client
```

## Test Your Deployment

```bash
# Get agent URL
AGENT_URL=$(terraform output -raw agent_url)

# Test with curl
curl -I $AGENT_URL/docs

# Open in browser
open $AGENT_URL/docs
```

You should see the Cognito login page!

## Using the Deployment Script

For automated deployment:

```bash
./deploy.sh
```

This script will:
1. Check prerequisites
2. Run terraform init/plan/apply
3. Guide you through Docker image building
4. Configure Cognito
5. Provide test commands

## Customization

Edit `terraform.tfvars` to customize:

```hcl
# Resource sizing
agent_task_cpu    = 512   # 0.5 vCPU
agent_task_memory = 1024  # 1 GB

# Logging
log_retention_days = 7    # CloudWatch retention

# S3 lifecycle
session_lifecycle_glacier_days = 30
session_lifecycle_expire_days  = 90

# WAF
enable_waf = true  # Set false to disable

# High availability
availability_zones = ["us-east-1a", "us-east-1b"]  # Multi-AZ
```

## Outputs

After deployment, get all outputs:

```bash
terraform output
```

Key outputs:
- `agent_url` - Access your agent here
- `agent_docs_url` - OpenAPI documentation
- `cognito_callback_url` - Add to Cognito
- `s3_sessions_bucket` - Where sessions are stored
- `workload_identity_name` - AgentCore Identity workload

## Troubleshooting

### Error: "No such image"
**Solution**: Build and push Docker images (Step 4)

### Error: "Target health checks failing"
**Check**: CloudWatch Logs for container errors
```bash
aws logs tail <log-group-name> --follow
```

### Error: "403 Forbidden" from Cognito
**Solution**: Add callback URL to Cognito app client

### Error: "ValidationException: Provider does not exist"
**Check**: GitHub provider name matches AgentCore Identity

## Next Steps

1. **Create Cognito Users**:
   ```bash
   aws cognito-idp admin-create-user \
     --user-pool-id <pool-id> \
     --username testuser
   ```

2. **Test OAuth Flow**:
   - Login with Cognito user
   - Ask agent: "Show me my GitHub profile"
   - Authorize on GitHub
   - Try again - should work!

3. **Monitor**:
   ```bash
   # Check ECS services
   aws ecs describe-services --cluster <cluster-name> --services <service-name>

   # View logs
   aws logs tail <log-group-name> --follow
   ```

4. **Scale**:
   ```bash
   # Update desired count in terraform.tfvars
   agent_desired_count = 2
   terraform apply
   ```

## Cleanup

To destroy all resources:

```bash
./destroy.sh
```

Or manually:

```bash
# Empty S3 buckets
aws s3 rm s3://<sessions-bucket> --recursive
aws s3 rm s3://<access-logs-bucket> --recursive

# Destroy infrastructure
terraform destroy
```

## Support

- **Documentation**: See [README.md](../../README.md)
- **Architecture**: See [ARCHITECTURE.md](../../ARCHITECTURE.md)
- **CDK Comparison**: See [CDK_VS_TERRAFORM.md](../../CDK_VS_TERRAFORM.md)
- **Issues**: File issues on GitHub

## Security Checklist

Before going to production:

- [ ] Enable MFA for AWS accounts
- [ ] Rotate secrets regularly
- [ ] Enable AWS CloudTrail
- [ ] Configure backup strategy
- [ ] Set up monitoring and alerts
- [ ] Review IAM policies
- [ ] Enable GuardDuty
- [ ] Configure AWS Config rules
- [ ] Test disaster recovery
- [ ] Document runbooks

## Cost Optimization

To reduce costs:

1. **Use Fargate Spot** (session binding already does)
2. **Reduce log retention** (set to 3 days for dev)
3. **Use single NAT Gateway** (already configured)
4. **Enable S3 Intelligent-Tiering**
5. **Delete unused resources**

Happy deploying! 🚀
