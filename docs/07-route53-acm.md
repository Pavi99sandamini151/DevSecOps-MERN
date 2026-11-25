# Route53 + ACM — delegated zone `devops.example.com`

Parent zone `example.com` already exists in your AWS account. This step creates a **child hosted zone** and NS-delegates it — no registrar changes.

| Host | Purpose |
|---|---|
| `devops.example.com` | MERN app |
| `argocd.devops.example.com` | ArgoCD |
| `grafana.devops.example.com` | Grafana |

Ordering (C7): apply DNS → copy ACM ARN into Ingress → then eks-post-setup.

## 1. Apply `infra/dns`

```bash
cd infra/dns
terraform init
terraform apply
terraform output acm_certificate_arn
terraform output devops_zone_id
cd ../..
```

Creates:

- Hosted zone `devops.example.com`
- NS record in `example.com` → child name servers
- ACM cert for `devops.example.com` + `*.devops.example.com` (DNS validated in child zone)

## 2. Paste ACM ARN into Ingress manifests

```bash
CERT_ARN=$(terraform -chdir=infra/dns output -raw acm_certificate_arn)
# Update annotation alb.ingress.kubernetes.io/certificate-arn in:
#   k8s/ingress.yaml
#   k8s/argocd-ingress.yaml
#   k8s/monitoring-ingress.yaml
```

Hosts are already set to `*.devops.example.com` in those files.

## 3. After ALB exists — A-alias records

Once Ingress creates the ALB, add alias records **in the devops zone** (`devops_zone_id`):

- `devops.example.com` → ALB
- `argocd.devops.example.com` → ALB (or same ALB if shared)
- `grafana.devops.example.com` → ALB

```bash
# Example — replace ALB_DNS and HOSTED_ZONE_ID from ALB + terraform output
aws route53 change-resource-record-sets --hosted-zone-id "$(terraform -chdir=infra/dns output -raw devops_zone_id)" --change-batch '{...}'
```

## Verify cert

```bash
aws acm describe-certificate \
  --certificate-arn "$(terraform -chdir=infra/dns output -raw acm_certificate_arn)" \
  --query Certificate.Status
# → ISSUED
```
