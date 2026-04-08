#!/bin/bash
set -e

echo "================================================"
echo "AgentCore 3LO OAuth Terraform Deployment"
echo "================================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
echo "Checking prerequisites..."

if ! command -v terraform &> /dev/null; then
    echo -e "${RED}❌ Terraform is not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Terraform installed${NC}"

if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI is not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ AWS CLI installed${NC}"

if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker is not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker installed${NC}"

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo -e "${RED}❌ terraform.tfvars not found${NC}"
    echo "Please copy terraform.tfvars.example to terraform.tfvars and configure it"
    exit 1
fi
echo -e "${GREEN}✓ terraform.tfvars found${NC}"

echo ""
echo "================================================"
echo "Phase 1: Initialize Terraform"
echo "================================================"
terraform init

echo ""
echo "================================================"
echo "Phase 2: Plan Infrastructure"
echo "================================================"
terraform plan -out=tfplan

echo ""
read -p "Do you want to apply this plan? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Deployment cancelled"
    exit 0
fi

echo ""
echo "================================================"
echo "Phase 3: Deploy Base Infrastructure"
echo "================================================"
echo -e "${YELLOW}Note: ECS services will fail initially (no Docker images yet)${NC}"
terraform apply tfplan || true

# Get ECR repository URLs
AGENT_REPO=$(terraform output -raw ecr_agent_repository_url 2>/dev/null || echo "")
SESSION_REPO=$(terraform output -raw ecr_session_binding_repository_url 2>/dev/null || echo "")
AWS_REGION=$(terraform output -json | jq -r '.aws_region.value' 2>/dev/null || echo "us-east-1")
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

if [ -z "$AGENT_REPO" ] || [ -z "$SESSION_REPO" ]; then
    echo -e "${RED}❌ Failed to get ECR repository URLs${NC}"
    exit 1
fi

echo ""
echo "================================================"
echo "Phase 4: Docker Image Management"
echo "================================================"
echo "ECR Repositories created:"
echo "  Agent: $AGENT_REPO"
echo "  Session Binding: $SESSION_REPO"
echo ""
echo -e "${YELLOW}⚠️  You need to build and push Docker images${NC}"
echo ""
echo "Option 1: Use existing CDK agent code"
echo "  cd ../../01-tutorials/03-AgentCore-identity/07-Outbound_Auth_3LO_ECS_Fargate"
echo ""
echo "Option 2: Provide your own Docker images"
echo ""
echo "To push images:"
echo "  1. Login to ECR:"
echo "     aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
echo ""
echo "  2. Build and push agent:"
echo "     docker build -t $AGENT_REPO:latest <agent-code-path>"
echo "     docker push $AGENT_REPO:latest"
echo ""
echo "  3. Build and push session binding:"
echo "     docker build -t $SESSION_REPO:latest <session-binding-code-path>"
echo "     docker push $SESSION_REPO:latest"
echo ""
read -p "Have you pushed the Docker images? (yes/no): " images_ready

if [ "$images_ready" != "yes" ]; then
    echo ""
    echo -e "${YELLOW}Please push Docker images and run: terraform apply${NC}"
    exit 0
fi

echo ""
echo "================================================"
echo "Phase 5: Deploy ECS Services"
echo "================================================"
terraform apply -auto-approve

echo ""
echo "================================================"
echo "Phase 6: Update Cognito Configuration"
echo "================================================"
CALLBACK_URL=$(terraform output -raw cognito_callback_url)
COGNITO_POOL_ID=$(terraform output -json | jq -r '.cognito_user_pool_id.value' 2>/dev/null || echo "")
COGNITO_CLIENT_ID=$(terraform output -json | jq -r '.cognito_client_id.value' 2>/dev/null || echo "")

echo "Add this callback URL to your Cognito app client:"
echo "  $CALLBACK_URL"
echo ""
echo "Run this command:"
echo "  aws cognito-idp update-user-pool-client \\"
echo "    --user-pool-id $COGNITO_POOL_ID \\"
echo "    --client-id $COGNITO_CLIENT_ID \\"
echo "    --callback-urls \"$CALLBACK_URL\" \\"
echo "    --supported-identity-providers \"COGNITO\" \\"
echo "    --allowed-o-auth-flows \"code\" \\"
echo "    --allowed-o-auth-scopes \"openid\" \"email\" \"profile\" \\"
echo "    --allowed-o-auth-flows-user-pool-client"
echo ""
read -p "Have you updated Cognito? (yes/no): " cognito_updated

echo ""
echo "================================================"
echo "✓ Deployment Complete!"
echo "================================================"
AGENT_URL=$(terraform output -raw agent_url)
echo "Agent URL: $AGENT_URL"
echo "Docs: $AGENT_URL/docs"
echo ""
echo "Test the agent:"
echo "  curl -I $AGENT_URL/docs"
echo ""
echo "Or open in browser:"
echo "  $AGENT_URL/docs"
echo ""
echo "================================================"
