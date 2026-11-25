#!/usr/bin/env bash
# =============================================================================
# EKS post-setup — run from the jump server (SSM) after Terraform EKS is up
# =============================================================================
# BEGINNER MAP
#   Terraform built the private EKS cluster + VPC. Kubernetes is empty.
#   This script installs the "platform layer" you need before the MERN app:
#     1) Namespaces (three-tier, argocd, monitoring, kyverno)
#     2) AWS Load Balancer Controller (turns Ingress → ALB)
#     3) ArgoCD (GitOps CD — watches the gitops branch)
#     4) Kyverno (admission policies — e.g. require signed images)
#     5) kube-prometheus-stack (metrics day-1)
#     6) MongoDB Secret (Bitnami chart key names)
#     7) Ingresses with your ACM certificate ARN injected
#
# WHY not do all of this in Terraform?
#   Helm charts + CRDs + one-time secrets are awkward/fragile as pure TF.
#   Operators also need a clear "run once after cluster exists" checklist.
#
# HOW
#   aws ssm start-session --target <jump_id>
#   export ACM_CERT_ARN=... MONGO_ROOT_PASSWORD=... MONGO_APP_PASSWORD=...
#   ./scripts/eks-post-setup.sh
#
# PRACTICE: C1 GitOps, C2/C10 IRSA + private UIs, C5 Kyverno+Cosign, G11 Mongo keys
# See also: docs/08-eks-post-setup.md, docs/16-design-decisions.md
# =============================================================================
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-devsecops-eks}"
REGION="${AWS_DEFAULT_REGION:-us-east-1}"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
DOMAIN="${DOMAIN:-devops.example.com}"
# Fail fast if the operator forgot required secrets/ARNs
ACM_CERT_ARN="${ACM_CERT_ARN:?Set ACM_CERT_ARN (terraform -chdir=infra/dns output -raw acm_certificate_arn)}"
GITLAB_REPO="${GITLAB_REPO:-https://gitlab.com/YOUR_GITLAB_NAMESPACE/devsecops-mern-eks.git}"

# ----- kubeconfig for the PRIVATE API -----
# This only works from the jump host (or peered network). Your laptop will time out (C10).
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"

# ---------------------------------------------------------------------------
# 1) Namespaces
# ---------------------------------------------------------------------------
# WHY separate namespaces?
#   Isolation + clearer RBAC. Apps, CD, observability, and policy engines
#   should not share one giant "default" namespace (C2 / C10).
# dry-run|apply = idempotent create (safe to re-run the script).
for ns in three-tier argocd monitoring kyverno; do
  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
done

# ---------------------------------------------------------------------------
# 2) AWS Load Balancer Controller (IRSA)
# ---------------------------------------------------------------------------
# WHAT: Watches Ingress objects and creates/updates AWS Application Load Balancers.
# WHY IRSA (IAM Roles for Service Accounts)?
#   The controller needs AWS API permission. IRSA gives a pod a short-lived role
#   instead of stuffing long-lived keys on the node instance profile (C2).
# ---------------------------------------------------------------------------
curl -sL -o /tmp/iam_policy.json \
  https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
# Idempotent: policy may already exist from a prior run
aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file:///tmp/iam_policy.json 2>/dev/null || true

# Creates the ServiceAccount + IAM role link that the Helm chart will use
eksctl create iamserviceaccount \
  --cluster="$CLUSTER_NAME" \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --attach-policy-arn="arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy" \
  --override-existing-serviceaccounts \
  --approve \
  --region "$REGION"

helm repo add eks https://aws.github.io/eks-charts
helm repo update
# Discover VPC ID from the cluster if the operator did not export VPC_ID
VPC_ID="${VPC_ID:-$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" --query 'cluster.resourcesVpcConfig.vpcId' --output text)}"
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --version 1.8.2 \
  -f helm-values/alb-controller-values.yaml \
  --set clusterName="$CLUSTER_NAME" \
  --set region="$REGION" \
  --set vpcId="$VPC_ID" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

# ---------------------------------------------------------------------------
# 3) ArgoCD
# ---------------------------------------------------------------------------
# WHAT: Continuously syncs Kubernetes manifests from git → cluster.
# WHY ArgoCD instead of `kubectl apply` from CI?
#   CI should build/push/sign. The cluster should converge from git (audit trail,
#   drift detection, self-heal) — practice C1 GitOps.
# ClusterIP: do NOT expose a public LoadBalancer; reach UI via Ingress + ACM (C10).
# ---------------------------------------------------------------------------
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd patch svc argocd-server -p '{"spec":{"type":"ClusterIP"}}'
# AppProjects separate app vs platform RBAC / allowed destinations (C2)
kubectl apply -f k8s/argocd-apps/appproject-cluster-tools.yaml
kubectl apply -f k8s/argocd-apps/appproject-three-tier.yaml

# ---------------------------------------------------------------------------
# 4) Kyverno
# ---------------------------------------------------------------------------
# WHAT: Kubernetes admission controller that enforces policies as YAML.
# WHY: Later we require Cosign-signed images before pods can start (C5 / C10).
# Policies themselves are applied via ArgoCD (keep policy-as-code in git).
# ---------------------------------------------------------------------------
helm repo add kyverno https://kyverno.github.io/kyverno/
helm upgrade --install kyverno kyverno/kyverno -n kyverno --create-namespace \
  --version 3.2.6 \
  -f helm-values/kyverno-values.yaml
# Kyverno must auth to private ECR to verify Cosign signatures (else 401 on sync).
# Run after install: ./scripts/kyverno-ecr-access.sh

# ---------------------------------------------------------------------------
# 5) Monitoring bootstrap (Prometheus / Grafana)
# ---------------------------------------------------------------------------
# WHAT: kube-prometheus-stack = Prometheus + Grafana + Alertmanager + node exporters.
# WHY day-1 metrics?
#   You need CPU/mem/pod health before chasing app bugs.
# Loki / Fluent Bit / Jaeger / OTel are installed later as Argo multi-source apps
# so their values stay in git (C1) — see observability-apps.yaml.
# ---------------------------------------------------------------------------
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  --version 58.7.2 \
  -f helm-values/prometheus-stack-values.yaml

echo "After ArgoCD is up, apply k8s/argocd-apps/observability-apps.yaml for Loki, Fluent Bit, Jaeger, OTel."

# ---------------------------------------------------------------------------
# 6) MongoDB credentials Secret
# ---------------------------------------------------------------------------
# WHAT: Kubernetes Secret the Bitnami MongoDB chart reads for users/passwords.
# WHY these exact key names?
#   Wrong keys → CrashLoopBackOff that looks like a DB bug (G11).
# Never commit real passwords; pass them via env when you run this script.
# ---------------------------------------------------------------------------
kubectl create secret generic mongo-sec \
  --namespace three-tier \
  --from-literal=mongodb-root-user=admin \
  --from-literal=mongodb-root-password="${MONGO_ROOT_PASSWORD:?Set MONGO_ROOT_PASSWORD}" \
  --from-literal=mongodb-username=appUser \
  --from-literal=mongodb-password="${MONGO_APP_PASSWORD:?Set MONGO_APP_PASSWORD}" \
  --dry-run=client -o yaml | kubectl apply -f -

# ---------------------------------------------------------------------------
# 7) Ingresses — inject ACM ARN for HTTPS on *.${DOMAIN}
# ---------------------------------------------------------------------------
# WHAT: Creates Ingress objects; ALB controller provisions an HTTPS ALB.
# WHY sed the ARN in?
#   Manifests in git keep a REPLACE_ placeholder so secrets/account IDs are not
#   hard-coded. We inject the real ACM ARN at apply time.
# WAF (from Terraform) attaches to the ALB these Ingresses create (C10).
# ---------------------------------------------------------------------------
sed "s|arn:aws:acm:us-east-1:ACCOUNT_ID:certificate/REPLACE_ACM_CERT_ARN|${ACM_CERT_ARN}|g" \
  k8s/argocd-ingress.yaml | kubectl apply -f -
sed "s|arn:aws:acm:us-east-1:ACCOUNT_ID:certificate/REPLACE_ACM_CERT_ARN|${ACM_CERT_ARN}|g" \
  k8s/monitoring-ingress.yaml | kubectl apply -f -

# ----- Operator hand-off -----
echo "Initial ArgoCD admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
echo
echo "Next: connect GitLab repo ${GITLAB_REPO} (gitops branch) in ArgoCD UI,"
echo "      apply k8s/argocd-apps/applications.yaml and k8s/argocd-apps/observability-apps.yaml"
