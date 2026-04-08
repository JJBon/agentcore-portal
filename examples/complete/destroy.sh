#!/bin/bash
set -e

echo "================================================"
echo "AgentCore 3LO OAuth Infrastructure Cleanup"
echo "================================================"
echo ""

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${RED}⚠️  WARNING: This will destroy all infrastructure!${NC}"
echo ""
read -p "Are you sure you want to destroy everything? (type 'yes' to confirm): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Destroy cancelled"
    exit 0
fi

echo ""
echo "================================================"
echo "Step 1: Empty S3 Buckets"
echo "================================================"

SESSIONS_BUCKET=$(terraform output -raw s3_sessions_bucket 2>/dev/null || echo "")
ACCESS_LOGS_BUCKET=$(terraform output -raw s3_access_logs_bucket 2>/dev/null || echo "")

if [ -n "$SESSIONS_BUCKET" ]; then
    echo "Emptying sessions bucket: $SESSIONS_BUCKET"
    aws s3 rm "s3://$SESSIONS_BUCKET" --recursive || true
    echo -e "${GREEN}✓ Sessions bucket emptied${NC}"
else
    echo -e "${YELLOW}⚠️  Could not find sessions bucket${NC}"
fi

if [ -n "$ACCESS_LOGS_BUCKET" ]; then
    echo "Emptying access logs bucket: $ACCESS_LOGS_BUCKET"
    aws s3 rm "s3://$ACCESS_LOGS_BUCKET" --recursive || true
    echo -e "${GREEN}✓ Access logs bucket emptied${NC}"
else
    echo -e "${YELLOW}⚠️  Could not find access logs bucket${NC}"
fi

echo ""
echo "================================================"
echo "Step 2: Delete ECR Images"
echo "================================================"

AGENT_REPO=$(terraform output -raw ecr_agent_repository_url 2>/dev/null | cut -d'/' -f2 || echo "")
SESSION_REPO=$(terraform output -raw ecr_session_binding_repository_url 2>/dev/null | cut -d'/' -f2 || echo "")
AWS_REGION=$(terraform output -json | jq -r '.aws_region.value' 2>/dev/null || echo "us-east-1")

if [ -n "$AGENT_REPO" ]; then
    echo "Deleting images from agent repository: $AGENT_REPO"
    aws ecr batch-delete-image \
        --repository-name "$AGENT_REPO" \
        --image-ids "$(aws ecr list-images --repository-name "$AGENT_REPO" --region "$AWS_REGION" --query 'imageIds[*]' --output json)" \
        --region "$AWS_REGION" 2>/dev/null || true
    echo -e "${GREEN}✓ Agent images deleted${NC}"
fi

if [ -n "$SESSION_REPO" ]; then
    echo "Deleting images from session binding repository: $SESSION_REPO"
    aws ecr batch-delete-image \
        --repository-name "$SESSION_REPO" \
        --image-ids "$(aws ecr list-images --repository-name "$SESSION_REPO" --region "$AWS_REGION" --query 'imageIds[*]' --output json)" \
        --region "$AWS_REGION" 2>/dev/null || true
    echo -e "${GREEN}✓ Session binding images deleted${NC}"
fi

echo ""
echo "================================================"
echo "Step 3: Stop ECS Tasks"
echo "================================================"

CLUSTER_NAME=$(terraform output -raw ecs_cluster_name 2>/dev/null || echo "")
if [ -n "$CLUSTER_NAME" ]; then
    echo "Stopping ECS tasks in cluster: $CLUSTER_NAME"
    TASK_ARNS=$(aws ecs list-tasks --cluster "$CLUSTER_NAME" --region "$AWS_REGION" --query 'taskArns[*]' --output text 2>/dev/null || echo "")

    if [ -n "$TASK_ARNS" ]; then
        for task in $TASK_ARNS; do
            aws ecs stop-task --cluster "$CLUSTER_NAME" --task "$task" --region "$AWS_REGION" 2>/dev/null || true
        done
        echo -e "${GREEN}✓ ECS tasks stopped${NC}"
    else
        echo "No running tasks found"
    fi
else
    echo -e "${YELLOW}⚠️  Could not find ECS cluster${NC}"
fi

echo ""
echo "================================================"
echo "Step 4: Destroy Terraform Infrastructure"
echo "================================================"

terraform destroy -auto-approve

echo ""
echo "================================================"
echo "Step 5: Cleanup Local Files"
echo "================================================"

echo "Removing Terraform state files..."
rm -f tfplan
rm -f .terraform.lock.hcl
rm -rf .terraform
echo -e "${GREEN}✓ Local files cleaned${NC}"

echo ""
echo "================================================"
echo "✓ Cleanup Complete!"
echo "================================================"
echo ""
echo "All resources have been destroyed."
echo ""
echo "You may need to manually delete:"
echo "  - CloudWatch Log Groups (if retention was set)"
echo "  - Secrets Manager secrets (if deletion protection enabled)"
echo "  - KMS keys (scheduled for deletion)"
echo ""
