# ArgoCD Applications

## Why ArgoCD (GitOps)

CI builds, scans, signs, and **writes desired state** to git. ArgoCD continuously reconciles the cluster to that state (drift detection, audit trail, self-heal).

**Practice:** C1 GitOps. ArgoCD watches **`gitops`** (not `main`) so deploy commits stay separate from app PRs (C6).

Create the branch first:

```bash
./scripts/init-gitops-branch.sh
```

## Deploy order

Order matters: identities and policies before workloads; database before backend; ingress last among apps.

| Order | App | Path / chart | Namespace | Project |
|---|---|---|---|---|
| 1 | serviceaccounts | `k8s/serviceaccounts` | three-tier | three-tier-app |
| 2 | network-policies | `k8s/network-policies` | three-tier | three-tier-app |
| 3 | database | `k8s/database` | three-tier | three-tier-app |
| 4 | backend | `k8s/backend` | three-tier | three-tier-app |
| 5 | frontend | `k8s/frontend` | three-tier | three-tier-app |
| 6 | ingress | `k8s/ingress.yaml` | three-tier | three-tier-app |
| 7 | pdb | `k8s/pdb` | three-tier | three-tier-app |
| 8 | kyverno-policies | `k8s/kyverno-policies` | kyverno | cluster-tools |
| 9 | observability-crds | `k8s/observability` | three-tier | cluster-tools |
| 10 | loki / fluent-bit / jaeger / otel-collector | Helm (multi-source) | monitoring | cluster-tools |

Manifests live in `k8s/argocd-apps/` (`applications.yaml` + `observability-apps.yaml`).

**Sync policy:** `prune: false` (avoid accidental deletes), `selfHeal: true` (drift correction) — C1 / C10.

## Helm charts (pinned)

Pinned chart versions keep upgrades intentional and reproducible.

| Component | Repo | Chart | Version |
|---|---|---|---|
| Kyverno | https://kyverno.github.io/kyverno/ | kyverno | 3.2.6 |
| kube-prometheus-stack | https://prometheus-community.github.io/helm-charts | kube-prometheus-stack | 58.7.2 |
| aws-load-balancer-controller | https://aws.github.io/eks-charts | aws-load-balancer-controller | 1.8.2 |
| Loki | https://grafana.github.io/helm-charts | loki | 6.16.0 |
| Fluent Bit | https://fluent.github.io/helm-charts | fluent-bit | 0.47.9 |
| Jaeger | https://jaegertracing.github.io/helm-charts | jaeger | 3.3.5 |
| OpenTelemetry Collector | https://open-telemetry.github.io/opentelemetry-helm-charts | opentelemetry-collector | 0.109.0 |
