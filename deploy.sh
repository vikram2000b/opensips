#!/bin/bash
#
# Deploy OpenSIPS to ECS
#

set -e

# Configuration
CLUSTER_NAME="your-cluster-name"
SERVICE_NAME="sage-opensips"
TASK_FAMILY="sage-opensips"
REGION="ap-south-1"

# Subnets (use your public subnets)
SUBNETS="subnet-052f4445b761dd52f,subnet-03be381ce75d1086c,subnet-006a73cb8a684922b"

# Security Groups (use your existing SG)
SECURITY_GROUPS="sg-04e66eaedf124b5a3"

echo "===================================="
echo "Deploying OpenSIPS to ECS"
echo "===================================="

# Step 1: Verify ECR image exists
echo "Step 1: Verifying Docker image in ECR..."
echo "Make sure you've built and pushed the image:"
echo "  docker build -t sage-opensips ."
echo "  docker tag sage-opensips:latest YOUR_ACCOUNT.dkr.ecr.ap-south-1.amazonaws.com/sage-opensips:latest"
echo "  docker push YOUR_ACCOUNT.dkr.ecr.ap-south-1.amazonaws.com/sage-opensips:latest"
echo ""
read -p "Press enter once image is in ECR..."

# Step 2: Register task definition
echo "Step 2: Registering ECS task definition..."
aws ecs register-task-definition \
  --cli-input-json file://ecs/task-definition.json \
  --region $REGION

# Step 3: Create ECS service (if doesn't exist)
echo "Step 3: Creating ECS service..."

# Check if service exists
if aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --region $REGION | grep -q "ACTIVE"; then
  echo "Service already exists. Updating..."
  aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service $SERVICE_NAME \
    --task-definition $TASK_FAMILY \
    --force-new-deployment \
    --region $REGION
else
  echo "Creating new service..."
  aws ecs create-service \
    --cluster $CLUSTER_NAME \
    --service-name $SERVICE_NAME \
    --task-definition $TASK_FAMILY \
    --desired-count 2 \
    --launch-type EC2 \
    --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS],securityGroups=[$SECURITY_GROUPS],assignPublicIp=DISABLED}" \
    --region $REGION
fi

echo ""
echo "===================================="
echo "Deployment Complete!"
echo "===================================="
echo ""
echo "Check service status:"
echo "  aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --region $REGION"
echo ""
echo "View logs:"
echo "  aws logs tail /ecs/sage-opensips --follow --region $REGION"
