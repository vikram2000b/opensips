# OpenSIPS ECS Service

OpenSIPS SIP router for sage-voice-manager. Routes SIP trunk calls to the Python media server.

## Architecture

```
SIP Trunk → NLB (5060 UDP/TCP) → OpenSIPS ECS Service → Media Server ECS Service
```

## Files

```
opensips-repo/
├── config/
│   └── opensips.cfg           # OpenSIPS configuration
├── ecs/
│   └── task-definition.json   # ECS task definition
├── deploy.sh                  # Deployment script
└── README.md                  # This file
```

## Prerequisites

1. **Existing ECS Cluster** with EC2 instances (c8g recommended)
2. **Media Server ECS Service** already running
3. **Security Group** allowing ports 5060 UDP/TCP
4. **Public Subnets** with Internet Gateway
5. **AWS CLI** configured with appropriate permissions

## Quick Start

### 1. Update Configuration

Edit `config/opensips.cfg` and update the media server address:

```
# Line 73 - Update this:
$du = "sip:YOUR_MEDIA_SERVER_IP:80";
```

Replace `YOUR_MEDIA_SERVER_IP` with:
- Media server's private IP (e.g., `10.0.1.20`)
- Or Cloud Map service discovery DNS (e.g., `sage-media-server.local`)
- Or internal NLB DNS

### 2. Update Deploy Script

Edit `deploy.sh` and set your values:

```bash
CLUSTER_NAME="your-cluster-name"      # Your ECS cluster name
SUBNETS="subnet-xxx,subnet-yyy"       # Your public subnet IDs
SECURITY_GROUPS="sg-xxxxx"            # Your security group ID
```

### 3. Copy Config to EC2 Instances

OpenSIPS config needs to be available on all EC2 instances. SSH to each instance:

```bash
# On each EC2 instance in your ECS cluster:
sudo mkdir -p /opt/opensips
sudo vi /opt/opensips/opensips.cfg  # Paste config from config/opensips.cfg
```

Or use Systems Manager:

```bash
aws ssm send-command \
  --document-name "AWS-RunShellScript" \
  --targets "Key=tag:Name,Values=your-ecs-instance-tag" \
  --parameters 'commands=["mkdir -p /opt/opensips","cat > /opt/opensips/opensips.cfg <<EOF
# Paste opensips.cfg contents here
EOF"]'
```

### 4. Deploy to ECS

```bash
chmod +x deploy.sh
./deploy.sh
```

## Manual Deployment (Alternative)

If you prefer manual deployment:

### Register Task Definition

```bash
aws ecs register-task-definition \
  --cli-input-json file://ecs/task-definition.json \
  --region ap-south-1
```

### Create Service

```bash
aws ecs create-service \
  --cluster your-cluster-name \
  --service-name sage-opensips \
  --task-definition sage-opensips \
  --desired-count 2 \
  --launch-type EC2 \
  --network-configuration "awsvpcConfiguration={
    subnets=[subnet-052f4445b761dd52f,subnet-03be381ce75d1086c],
    securityGroups=[sg-04e66eaedf124b5a3],
    assignPublicIp=DISABLED
  }" \
  --region ap-south-1
```

## Network Load Balancer Setup

Create NLB to route external SIP traffic to OpenSIPS:

### Create Target Group

```bash
aws elbv2 create-target-group \
  --name sage-opensips-udp \
  --protocol UDP \
  --port 5060 \
  --vpc-id vpc-xxxxx \
  --target-type ip \
  --health-check-protocol TCP \
  --health-check-port 5060
```

### Create NLB

```bash
aws elbv2 create-load-balancer \
  --name sage-sip-nlb \
  --type network \
  --scheme internet-facing \
  --subnets subnet-052f4445b761dd52f subnet-03be381ce75d1086c
```

### Create Listener

```bash
aws elbv2 create-listener \
  --load-balancer-arn arn:aws:elasticloadbalancing:... \
  --protocol UDP \
  --port 5060 \
  --default-actions Type=forward,TargetGroupArn=arn:aws:elasticloadbalancing:...
```

### Attach Service to NLB

Update the ECS service to use the target group:

```bash
aws ecs update-service \
  --cluster your-cluster-name \
  --service sage-opensips \
  --load-balancers "targetGroupArn=arn:aws:elasticloadbalancing:...,containerName=opensips,containerPort=5060"
```

## Service Discovery (Recommended)

Use AWS Cloud Map for service discovery so OpenSIPS can find media servers automatically:

```bash
# Create private DNS namespace
aws servicediscovery create-private-dns-namespace \
  --name local \
  --vpc vpc-xxxxx

# Register media server service
aws servicediscovery create-service \
  --name sage-media-server \
  --dns-config "NamespaceId=ns-xxxxx,DnsRecords=[{Type=A,TTL=10}]" \
  --health-check-custom-config FailureThreshold=1
```

Then update OpenSIPS config:
```
$du = "sip:sage-media-server.local:80";
```

## Monitoring

### View Logs

```bash
# Tail logs
aws logs tail /ecs/sage-opensips --follow

# Query specific errors
aws logs filter-pattern /ecs/sage-opensips --filter-pattern "ERROR"
```

### Check Service Status

```bash
aws ecs describe-services \
  --cluster your-cluster-name \
  --services sage-opensips
```

### Check Task Health

```bash
aws ecs list-tasks --cluster your-cluster-name --service-name sage-opensips

aws ecs describe-tasks \
  --cluster your-cluster-name \
  --tasks task-arn
```

## Testing

### Test SIP Connectivity

From a machine with SIP tools installed:

```bash
# Using sipsak
sipsak -vv -s sip:test@your-nlb-dns:5060

# Using sipp
sipp -sn uac your-nlb-dns:5060
```

### Test from SIP Trunk Provider

Configure your SIP trunk provider to send calls to:
- **Host:** Your NLB DNS or IP
- **Port:** 5060 (UDP/TCP)
- **Protocol:** SIP

## Scaling

### Manual Scaling

```bash
aws ecs update-service \
  --cluster your-cluster-name \
  --service sage-opensips \
  --desired-count 4
```

### Auto Scaling

```bash
# Register scalable target
aws application-autoscaling register-scalable-target \
  --service-namespace ecs \
  --resource-id service/your-cluster-name/sage-opensips \
  --scalable-dimension ecs:service:DesiredCount \
  --min-capacity 2 \
  --max-capacity 10

# Create scaling policy
aws application-autoscaling put-scaling-policy \
  --service-namespace ecs \
  --resource-id service/your-cluster-name/sage-opensips \
  --scalable-dimension ecs:service:DesiredCount \
  --policy-name cpu-scaling \
  --policy-type TargetTrackingScaling \
  --target-tracking-scaling-policy-configuration '{
    "TargetValue": 70.0,
    "PredefinedMetricSpecification": {
      "PredefinedMetricType": "ECSServiceAverageCPUUtilization"
    }
  }'
```

## Troubleshooting

### OpenSIPS Not Starting

Check task logs:
```bash
aws logs tail /ecs/sage-opensips --follow
```

Common issues:
- Config file not found at `/opt/opensips/opensips.cfg` on EC2 instances
- Syntax error in `opensips.cfg`
- Port 5060 already in use

### Calls Not Routing to Media Server

1. Check OpenSIPS logs for routing errors
2. Verify media server IP/DNS in `opensips.cfg`
3. Check security groups allow traffic between OpenSIPS and media server
4. Test connectivity: `docker exec opensips-container ping media-server-ip`

### SIP Trunk Can't Reach OpenSIPS

1. Verify NLB is created and listener is configured
2. Check target group health
3. Verify security group allows inbound 5060 UDP/TCP from 0.0.0.0/0
4. Check SIP trunk provider's IP is not blocked

## Configuration Reference

### OpenSIPS Config (`config/opensips.cfg`)

Key settings:
- **Line 9-10:** Listening ports (5060 UDP/TCP)
- **Line 73:** Media server destination (`$du`)
- **Line 12-14:** TCP settings
- **Line 30-38:** Module parameters

### Task Definition (`ecs/task-definition.json`)

Key settings:
- **cpu/memory:** 256/512 (increase if needed)
- **portMappings:** 5060 UDP and TCP
- **volumes:** Maps config from EC2 host
- **logConfiguration:** CloudWatch logs group

## Cost Optimization

Current configuration:
- **CPU:** 0.25 vCPU (256 units)
- **Memory:** 512 MB
- **Cost:** ~$7/month per task (EC2 launch type)

For 2 tasks: ~$14/month (very cheap!)

## Security

### Production Recommendations:

1. **Restrict security group** to known SIP trunk IPs
2. **Enable TLS** for SIP over TLS (port 5061)
3. **Add authentication** in OpenSIPS config
4. **Rate limiting** to prevent abuse
5. **Firewall rules** for DDoS protection

## Support

For issues or questions:
1. Check OpenSIPS logs: `aws logs tail /ecs/sage-opensips --follow`
2. Check ECS service events: `aws ecs describe-services ...`
3. Review OpenSIPS documentation: https://www.opensips.org/Documentation
