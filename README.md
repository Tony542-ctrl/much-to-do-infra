# Much-to-Do Infrastructure

Production-ready AWS infrastructure for the **Much-to-Do** task management application, provisioned entirely using **Terraform** (Infrastructure as Code).

## Architecture

```
                        ┌─────────────────────────────────────────────────────┐
                        │                   AWS Cloud (us-east-1)             │
                        │                                                     │
   Users ──HTTPS──►     │  ┌──────────────┐        ┌──────────────────┐      │
                        │  │  CloudFront   │◄──OAC──│  S3 Bucket       │      │
                        │  │  Distribution │        │  (React Build)   │      │
                        │  └──────────────┘        └──────────────────┘      │
                        │                                                     │
   Users ──HTTP──►      │  ┌───────────────────────────────────────────┐      │
                        │  │        Application Load Balancer (ALB)     │      │
                        │  │           (Public Subnets, 2 AZs)         │      │
                        │  └────────────┬──────────────┬───────────────┘      │
                        │               │              │                      │
                        │     ┌─────────┼──────────────┼──────────┐          │
                        │     │   VPC   │  10.0.0.0/16 │          │          │
                        │     │         ▼              ▼          │          │
                        │     │  ┌────────────┐ ┌────────────┐   │          │
                        │     │  │ EC2 (AZ-a) │ │ EC2 (AZ-b) │   │          │
                        │     │  │ Private     │ │ Private     │   │          │
                        │     │  │ 10.0.1.0/24│ │ 10.0.2.0/24│   │          │
                        │     │  └─────┬──────┘ └─────┬──────┘   │          │
                        │     │        │              │           │          │
                        │     │        └──────┬───────┘           │          │
                        │     │               ▼                   │          │
                        │     │       ┌──────────────┐           │          │
                        │     │       │ ElastiCache  │           │          │
                        │     │       │ Redis (:6379)│           │          │
                        │     │       └──────────────┘           │          │
                        │     └───────────────────────────────────┘          │
                        │                     │                              │
                        │              NAT Gateway                           │
                        │                     │                              │
                        │                     ▼                              │
                        │            MongoDB Atlas (External)                │
                        │                                                     │
                        │     CloudWatch Logs: /much-to-do/backend           │
                        └─────────────────────────────────────────────────────┘
```

## Repository Structure

```
much-to-do-infra/
├── .gitignore
├── README.md
├── terraform/
│   ├── backend.tf              # S3 remote state backend
│   ├── provider.tf             # AWS provider configuration
│   ├── variables.tf            # Input variables
│   ├── vpc.tf                  # VPC, subnets, IGW, NAT Gateway
│   ├── security-groups.tf      # Security groups (ALB, EC2, Redis, Bastion)
│   ├── alb.tf                  # Application Load Balancer + Target Group
│   ├── ec2.tf                  # EC2 instances (2x backend + bastion)
│   ├── s3-cloudfront.tf        # S3 bucket + CloudFront distribution
│   ├── elasticache.tf          # Redis cluster
│   ├── cloudwatch.tf           # Log group
│   ├── iam.tf                  # IAM roles & policies
│   ├── outputs.tf              # Output values
│   └── terraform.tfvars.example
├── scripts/
│   ├── user-data.sh            # EC2 bootstrap script
│   └── deploy-backend.sh       # Rolling deployment helper
└── templates/
    ├── much-to-do.service      # Systemd unit file
    └── amazon-cloudwatch-agent.json
```

## Prerequisites

1. **AWS CLI** configured with credentials (`aws configure`)
2. **Terraform** >= 1.5.0 installed
3. **MongoDB Atlas** free-tier cluster created in `us-east-1`
4. **SSH Key Pair** created in AWS EC2 Console

## Quick Start

### 1. Create Remote State Backend (one-time)
```bash
aws s3 mb s3://much-to-do-tfstate
aws dynamodb create-table \
  --table-name much-to-do-tf-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

### 2. Configure Variables
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

### 3. Deploy Infrastructure
```bash
terraform init
terraform plan
terraform apply
```

### 4. Post-Deployment
After `terraform apply` completes:
1. **Whitelist NAT Gateway EIP** in MongoDB Atlas Network Access
2. **Set GitHub Secrets** using the Terraform outputs:
   - `ALB_DNS_URL` → `http://<alb_dns_name>`
   - `S3_BUCKET_NAME` → from `s3_bucket_name` output
   - `CLOUDFRONT_DISTRIBUTION_ID` → from `cloudfront_distribution_id` output
   - `BASTION_HOST` → from `bastion_public_ip` output
   - `EC2_HOST_1`, `EC2_HOST_2` → from `backend_private_ips` output
3. **Push to main** in the app repo to trigger CI/CD

## Security Features

- ✅ EC2 instances in **private subnets** (no public IPs)
- ✅ Security groups with **least-privilege** rules
- ✅ S3 bucket has **no public access** (CloudFront OAC only)
- ✅ Sensitive variables marked as `sensitive` in Terraform
- ✅ No secrets committed to git (`.gitignore` + `.tfvars`)
- ✅ All outbound traffic routed via **NAT Gateway**
- ✅ HTTPS enforced on CloudFront

## High Availability

- ✅ 2 EC2 instances across **2 Availability Zones**
- ✅ ALB distributes traffic with **health checks** (`/health`)
- ✅ If one instance fails, ALB routes to the healthy instance

## Observability

- ✅ Backend logs shipped to **CloudWatch Logs** via the CW Agent
- ✅ Log group: `/much-to-do/backend`
- ✅ Retention: 14 days
- ✅ Each instance logs to its own stream (named by instance ID)

## CI/CD Integration

The application repository contains GitHub Actions workflows:

| Workflow | Trigger | Action |
|:---|:---|:---|
| `deploy-frontend.yml` | Push to `main` (Client/** changes) | Build React → S3 sync → CF invalidation |
| `deploy-backend.yml` | Push to `main` (Server/** changes) | Build Go → Rolling deploy via SSH |

### Required GitHub Secrets
| Secret | Source |
|:---|:---|
| `AWS_ACCESS_KEY_ID` | IAM user credentials |
| `AWS_SECRET_ACCESS_KEY` | IAM user credentials |
| `AWS_REGION` | `us-east-1` |
| `S3_BUCKET_NAME` | Terraform output: `s3_bucket_name` |
| `CLOUDFRONT_DISTRIBUTION_ID` | Terraform output: `cloudfront_distribution_id` |
| `ALB_DNS_URL` | Terraform output: `http://<alb_dns_name>` |
| `BASTION_HOST` | Terraform output: `bastion_public_ip` |
| `EC2_HOST_1` | Terraform output: `backend_private_ips[0]` |
| `EC2_HOST_2` | Terraform output: `backend_private_ips[1]` |
| `SSH_PRIVATE_KEY` | Your EC2 key pair private key |

## Estimated Monthly Cost (Free Tier Eligible)

| Resource | Type | Est. Cost |
|:---|:---|:---|
| EC2 (2x) | t3.micro | ~$0 (free tier, then ~$15/mo) |
| NAT Gateway | Single | ~$32/mo |
| ALB | Application LB | ~$16/mo |
| ElastiCache | cache.t3.micro | ~$12/mo |
| S3 + CloudFront | Static hosting | ~$1/mo |
| MongoDB Atlas | M0 Free | $0 |
| **Total** | | **~$61/mo** (after free tier) |

## Teardown

```bash
cd terraform
terraform destroy
```

> ⚠️ Remember to also delete the S3 state bucket and DynamoDB lock table if no longer needed.
