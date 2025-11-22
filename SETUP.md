# OpenSIPS Setup Guide

Simple Docker-based deployment for OpenSIPS ECS service.

## Overview

This approach bakes the OpenSIPS configuration into a Docker image, eliminating the need to manage config files on EC2 instances.

**Flow:**
```
Code Change → Git Push → CodeBuild → ECR → ECS Deployment
```

## Prerequisites

1. **AWS Account** with ECS cluster
2. **ECR Repository** created (see below)
3. **CodeBuild Project** (optional, for CI/CD)
4. **Media Server** running in same VPC

## One-Time Setup

### 1. Create ECR Repository

```bash
aws ecr create-repository \
  --repository-name sage-opensips \
  --region ap-south-1
```

Note the repository URI (e.g., `123456789.dkr.ecr.ap-south-1.amazonaws.com/sage-opensips`)

### 2. Update Configuration Files

**Update `config/opensips.cfg` (line 73):**
```
# Replace with your media server's private IP or DNS
$du = "sip:172.31.14.250:80";
```

**Update `buildspec.yml` (line 30):**
```yaml
AWS_ACCOUNT_ID: "123456789"  # Your AWS account ID
```

**Update `ecs/task-definition.json` (line 10):**
```json
"image": "123456789.dkr.ecr.ap-south-1.amazonaws.com/sage-opensips:latest"
```

**Update `deploy.sh` (lines 7-11):**
```bash
CLUSTER_NAME="your-cluster-name"
SUBNETS="subnet-xxx,subnet-yyy"
SECURITY_GROUPS="sg-xxxxx"
```

## Deployment Options

### Option A: Manual Build & Deploy

```bash
# 1. Build Docker image
docker build -t sage-opensips .

# 2. Login to ECR
aws ecr get-login-password --region ap-south-1 | \
  docker login --username AWS --password-stdin \
  123456789.dkr.ecr.ap-south-1.amazonaws.com

# 3. Tag image
docker tag sage-opensips:latest \
  123456789.dkr.ecr.ap-south-1.amazonaws.com/sage-opensips:latest

# 4. Push to ECR
docker push 123456789.dkr.ecr.ap-south-1.amazonaws.com/sage-opensips:latest

# 5. Deploy to ECS
./deploy.sh
```

### Option B: CodeBuild CI/CD (Recommended)

**1. Create CodeBuild Project:**

```bash
aws codebuild create-project \
  --name sage-opensips-build \
  --source type=GITHUB,location=https://github.com/your-org/opensips-repo.git \
  --artifacts type=NO_ARTIFACTS \
  --environment type=LINUX_CONTAINER,image=aws/codebuild/standard:7.0,computeType=BUILD_GENERAL1_SMALL,privilegedMode=true \
  --service-role arn:aws:iam::123456789:role/CodeBuildServiceRole
```

**2. Trigger build:**
```bash
aws codebuild start-build --project-name sage-opensips-build
```

**3. Auto-deploy on push:**
Set up GitHub webhook to trigger CodeBuild on push to `main` branch.

## Making Configuration Changes

### Update OpenSIPS Config:

1. Edit `config/opensips.cfg`
2. Commit and push to Git
3. Build new Docker image (manual or via CodeBuild)
4. Deploy to ECS

```bash
# After editing config/opensips.cfg
git add config/opensips.cfg
git commit -m "Update OpenSIPS routing"
git push

# Rebuild image
docker build -t sage-opensips .
docker tag sage-opensips:latest ECR_URI:latest
docker push ECR_URI:latest

# Force ECS to pull new image
aws ecs update-service \
  --cluster your-cluster \
  --service sage-opensips \
  --force-new-deployment
```

## Verify Deployment

```bash
# Check service status
aws ecs describe-services \
  --cluster your-cluster \
  --services sage-opensips \
  --query 'services[0].{status:status,running:runningCount,desired:desiredCount}'

# View logs
aws logs tail /ecs/sage-opensips --follow

# Check tasks
aws ecs list-tasks --cluster your-cluster --service-name sage-opensips
```

## Architecture Benefits

✅ **No manual file copying** - Config baked into Docker image
✅ **Version controlled** - Config changes tracked in Git
✅ **Easy rollback** - Just deploy previous image tag
✅ **Works anywhere** - EC2, Fargate, local testing
✅ **Immutable infrastructure** - Reproducible deployments

## Local Testing

Test OpenSIPS locally before deploying:

```bash
# Build image
docker build -t sage-opensips .

# Run locally
docker run -p 5060:5060/udp -p 5060:5060/tcp sage-opensips

# Test SIP connectivity
# (from another terminal)
sipsak -vv -s sip:test@localhost:5060
```

## Troubleshooting

**Image build fails:**
- Check Dockerfile syntax
- Verify opensips.cfg is valid

**Can't push to ECR:**
- Ensure ECR repository exists
- Check AWS credentials
- Verify ECR login

**ECS tasks failing:**
- Check CloudWatch logs: `aws logs tail /ecs/sage-opensips --follow`
- Verify opensips.cfg syntax
- Check media server IP/DNS is correct

**SIP routing not working:**
- Verify media server address in opensips.cfg
- Check security groups allow traffic between services
- Review OpenSIPS logs for routing errors

## CI/CD Pipeline

For automated deployments:

```
GitHub Push → CodeBuild → Build Docker Image → Push to ECR → Update ECS Service
```

See **Option B** above for setup.

## Cost

- **Docker image storage (ECR):** ~$0.10/GB/month
- **ECS tasks (2x):** ~$14/month (EC2 launch type)
- **Total:** ~$15/month

## Next Steps

1. Set up NLB (see README.md)
2. Configure SIP trunk provider
3. Set up monitoring/alerts
4. Enable auto-scaling
