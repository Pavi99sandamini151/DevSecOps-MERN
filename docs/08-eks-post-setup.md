# EKS post-setup (from jump server)

All commands prefer SSM Session Manager on the jump instance (private EKS — C10).

Rationale for each install step: comments in [`scripts/eks-post-setup.sh`](../scripts/eks-post-setup.sh) and [`16-design-decisions.md`](./16-design-decisions.md).

## Why this script exists

Terraform brings up VPC/EKS/ECR. Post-setup installs **cluster add-ons and platform apps** (ALB controller IRSA, ArgoCD, Kyverno, Prometheus) plus one-time secrets and ACM injection — things that are painful or brittle as pure Terraform Helm releases in this lab.

| Step | Why | Practice |
|---|---|---|
| ALB controller + IRSA | Ingress → ALB without node IAM keys | C2 / C10 |
| ArgoCD ClusterIP + AppProjects | GitOps CD; UI not public LB | C1 / C10 |
| Kyverno | Later admit only signed images | C5 / C10 |
| kube-prometheus-stack | Day-1 metrics; other obs via Argo | C1 |
| `mongo-sec` | Bitnami chart key contract | G11 |
| Ingress + ACM ARN | HTTPS at the edge (+ WAF) | C10 |

## 1. Kubeconfig

```bash
aws eks update-kubeconfig --name devsecops-eks --region us-east-1
kubectl get nodes
```

## 2. Automated helper

From a checkout of this repo on the jump server (or copy `scripts/` / `helm-values/` / `k8s/`):

```bash
export DOMAIN=devops.example.com
export ACM_CERT_ARN=$(terraform -chdir=infra/dns output -raw acm_certificate_arn)
export GITLAB_REPO=https://gitlab.com/YOUR_GITLAB_NAMESPACE/devsecops-mern-eks.git
export MONGO_ROOT_PASSWORD='...'
export MONGO_APP_PASSWORD='...'
./scripts/eks-post-setup.sh
```

## 3. Manual checklist

1. Create namespaces: `three-tier`, `argocd`, `monitoring`, `kyverno`
2. Install AWS Load Balancer Controller (IRSA + Helm chart `1.8.x`)
3. Install ArgoCD; patch server Service to `ClusterIP`; apply Ingress
4. Create AppProjects `cluster-tools` and `three-tier-app`
5. Connect GitLab repo in ArgoCD (HTTPS + token with `read_repository`) — watch **`gitops`** (C1 / C6)
6. Create `mongo-sec` Secret (Bitnami keys — G11)
7. Install Kyverno Helm chart `3.2.x`
8. Apply ArgoCD Applications after `gitops` branch exists

## Mongo secret (exact)

```bash
kubectl create secret generic mongo-sec \
  --namespace three-tier \
  --from-literal=mongodb-root-user=admin \
  --from-literal=mongodb-root-password='STRONG_ROOT' \
  --from-literal=mongodb-username=appUser \
  --from-literal=mongodb-password='STRONG_APP'
```
