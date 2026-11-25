# EKS infrastructure via GitLab CI

Terraform module: [`infra/eks/`](../infra/eks/)

## Why private EKS + jump host

- **Private API** shrinks the attack surface (no public Kubernetes endpoint).
- **SSM jump** avoids distributing SSH keys; operators use Session Manager.

**Practice:** C10 defense in depth; C7 manual Terraform apply.

## Trigger

Preferred (avoids blocking app pipelines):

1. Change files under `infra/**` (or `ci/infra.gitlab-ci.yml`), **or**
2. GitLab → CI/CD → **Run pipeline** on `main` with variable `RUN_INFRA=true`

Then: play `tf-init` → review `tf-plan` → manual `tf-apply`.

See `ci/infra.gitlab-ci.yml` comments and [`11-ci-pipelines.md`](./11-ci-pipelines.md).

## What `infra/eks` creates

| Resource | Why |
|---|---|
| VPC public/private + NAT | Nodes private; controlled egress |
| Private EKS + managed nodes (IMDSv2) | No public API; harden metadata |
| Jump server (SSM) | Operator access without SSH keys |
| IRSA OIDC provider | Pods get AWS creds without node keys |
| ECR (immutable + scan) | Supply-chain baseline (C5) |
| KMS etcd encryption | Secrets at rest |
| CloudTrail + VPC Flow Logs | Audit / forensics |
| VPC endpoints (S3/ECR/STS/logs) | Keep AWS API traffic private |
| WAFv2 WebACL | Edge filtering for ALB |

## Verify from jump server

```bash
aws ssm start-session --target <jump_instance_id>
aws eks update-kubeconfig --name devsecops-eks --region us-east-1
kubectl get nodes
```

Private cluster: `kubectl` from your laptop will time out — use the jump server.
