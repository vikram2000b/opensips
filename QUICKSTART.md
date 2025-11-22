# Quick Start Guide

Deploy OpenSIPS ECS service in 5 minutes.

## Prerequisites Checklist

- [ ] ECS cluster running (with EC2 instances)
- [ ] Media server ECS service deployed
- [ ] Security group allows port 5060 UDP/TCP
- [ ] Public subnets configured
- [ ] AWS CLI installed and configured

## Step-by-Step Deployment

### 1. Get Media Server Private IP

Find your media server's private IP:

```bash
# List media server tasks
aws ecs list-tasks --cluster YOUR_CLUSTER --service-name YOUR_MEDIA_SERVICE

# Get task details
aws ecs describe-tasks --cluster YOUR_CLUSTER --tasks TASK_ARN \
  --query 'tasks[0].containers[0].networkInterfaces[0].privateIpv4Address'
```

Note this IP (e.g., `172.31.14.250`)

### 2. Update OpenSIPS Config

Edit `config/opensips.cfg`, line 73:

```
# Change from:
$du = "sip:sage-media-server.local:80";

# To (use the IP from step 1):
$du = "sip:172.31.14.250:80";
```

### 3. Copy Config to EC2 Instances

Get your EC2 instance IDs:

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=*ecs*" \
  --query 'Reservations[*].Instances[*].[InstanceId,PrivateIpAddress]' \
  --output table
```

SSH to each instance and copy config:

```bash
# SSH to instance
ssh ec2-user@INSTANCE_IP

# Create directory and copy config
sudo mkdir -p /opt/opensips
sudo nano /opt/opensips/opensips.cfg  # Paste contents from config/opensips.cfg

# Verify
cat /opt/opensips/opensips.cfg
```

### 4. Update Deploy Script

Edit `deploy.sh`:

```bash
# Update these lines:
CLUSTER_NAME="your-actual-cluster-name"  # Your ECS cluster
SUBNETS="subnet-052f4445b761dd52f,subnet-03be381ce75d1086c"  # Your subnets
SECURITY_GROUPS="sg-04e66eaedf124b5a3"  # Your security group
```

### 5. Deploy!

```bash
chmod +x deploy.sh
./deploy.sh
```

### 6. Verify Deployment

Check service is running:

```bash
aws ecs describe-services \
  --cluster YOUR_CLUSTER \
  --services sage-opensips \
  --query 'services[0].{status:status,running:runningCount,desired:desiredCount}'
```

Expected output:
```json
{
  "status": "ACTIVE",
  "running": 2,
  "desired": 2
}
```

Check logs:

```bash
aws logs tail /ecs/sage-opensips --follow
```

You should see OpenSIPS startup logs.

## Next Steps

### Optional: Create NLB

If you want external SIP trunks to reach OpenSIPS:

1. Create Network Load Balancer (see README.md)
2. Point your SIP trunk provider to the NLB DNS

### Test SIP Routing

From your media server logs, you should see SIP requests being forwarded by OpenSIPS.

## Troubleshooting

**Service won't start:**
- Check task logs: `aws logs tail /ecs/sage-opensips --follow`
- Verify config file exists on EC2: `ssh ec2-user@instance "cat /opt/opensips/opensips.cfg"`

**Can't find media server:**
- Verify media server IP in opensips.cfg
- Check security groups allow traffic between services
- Test: `aws ecs describe-tasks ...` to get media server IP

**Port conflicts:**
- Check if port 5060 is in use: `ssh ec2-user@instance "netstat -tuln | grep 5060"`

## Success!

Once deployed, OpenSIPS will:
- ✅ Listen on port 5060 (UDP/TCP)
- ✅ Route all SIP requests to your media server
- ✅ Handle SIP trunk calls
- ✅ Auto-scale with your cluster

**You're done!** 🎉
