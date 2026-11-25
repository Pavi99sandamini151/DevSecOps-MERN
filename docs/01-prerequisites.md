# Prerequisites

After setup, read [`16-design-decisions.md`](./16-design-decisions.md) for why each control exists.

## Accounts & access

- AWS account with billing enabled and admin access for bootstrap
- GitLab.com account and empty project `devsecops-mern-eks`
- Parent domain `example.com` already in Route53 (this project creates delegated zone `devops.example.com`)

## Local tools

- AWS CLI v2 (`aws configure`)
- Terraform >= 1.6
- `kubectl`, `eksctl`, `helm`, `cosign`, `git`
- Optional: `glab`

## AWS quotas (minimum)

- 2+ EC2 vCPUs available, 2 EIPs, room for VPC/NAT/EKS

## Before any Terraform apply

1. Create an EC2 key pair (or plan to use SSM only)
2. Know your public IP for SonarQube SG (`allowed_cidr` in `infra/runner/terraform.tfvars`)
3. After `infra/dns` apply, paste ACM ARN into `k8s/*ingress*.yaml` (hosts already use `devops.example.com`)
