#!/usr/bin/env bash
# =============================================================================
# Give Kyverno permission to read private ECR (Cosign verify)
# =============================================================================
# BEGINNER MAP
#   Kyverno verifyImages must FETCH the image manifest + Cosign signature from
#   the registry during admission. That call is made by the Kyverno *pod*, not
#   by the kubelet — so the EKS node instance role does NOT help.
#
#   Without credentials → 401 Unauthorized from ECR → ArgoCD sync blocked.
#
#   This script does two things (defense in depth):
#     1) IRSA on kyverno-admission-controller → long-lived AWS auth for ECR
#     2) docker-registry Secret in namespace kyverno (12h password; refreshed here)
#
# HOW (from jump host / SSM with kubectl + aws + eksctl + helm):
#   export CLUSTER_NAME=devsecops-eks AWS_DEFAULT_REGION=us-east-1
#   ./scripts/kyverno-ecr-access.sh
# =============================================================================
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-devsecops-eks}"
REGION="${AWS_DEFAULT_REGION:-us-east-1}"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
ROLE_NAME="${KYVERNO_ECR_ROLE_NAME:-kyverno-ecr-pull}"
# Helm release "kyverno" → this SA name (chart 3.x)
KYVERNO_SA="${KYVERNO_SA:-kyverno-admission-controller}"
KYVERNO_NS="${KYVERNO_NS:-kyverno}"
ECR_SECRET_NAME="${ECR_SECRET_NAME:-ecr-pull-secret}"
POLICY_NAME=AmazonEC2ContainerRegistryReadOnly

echo "==> Ensuring IRSA for ${KYVERNO_NS}/${KYVERNO_SA} → role ${ROLE_NAME}"
eksctl create iamserviceaccount \
  --cluster="$CLUSTER_NAME" \
  --region="$REGION" \
  --namespace="$KYVERNO_NS" \
  --name="$KYVERNO_SA" \
  --role-name="$ROLE_NAME" \
  --attach-policy-arn="arn:aws:iam::aws:policy/${POLICY_NAME}" \
  --override-existing-serviceaccounts \
  --approve

ROLE_ARN="$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)"
echo "Role ARN: ${ROLE_ARN}"

echo "==> Annotating Helm values path via helm upgrade (keeps IRSA on future upgrades)"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
helm repo add kyverno https://kyverno.github.io/kyverno/ >/dev/null 2>&1 || true
helm repo update kyverno >/dev/null
helm upgrade --install kyverno kyverno/kyverno -n "$KYVERNO_NS" --create-namespace \
  --version 3.2.6 \
  -f "${ROOT}/helm-values/kyverno-values.yaml" \
  --set "admissionController.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn=${ROLE_ARN}"

echo "==> Creating/refreshing docker-registry secret ${ECR_SECRET_NAME} (backup for verifyImages.imagePullSecrets)"
ECR_SERVER="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
ECR_PASS="$(aws ecr get-login-password --region "$REGION")"
kubectl create secret docker-registry "$ECR_SECRET_NAME" \
  -n "$KYVERNO_NS" \
  --docker-server="$ECR_SERVER" \
  --docker-username=AWS \
  --docker-password="$ECR_PASS" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "==> Restarting Kyverno admission pods so they pick up IRSA"
kubectl -n "$KYVERNO_NS" rollout restart deployment/kyverno-admission-controller
kubectl -n "$KYVERNO_NS" rollout status deployment/kyverno-admission-controller --timeout=180s

echo
echo "Done. Re-sync the ArgoCD backend/frontend apps."
echo "Note: docker-registry ECR passwords expire ~12h — re-run this script or add a CronJob;"
echo "      IRSA does not expire and is the preferred auth path."
