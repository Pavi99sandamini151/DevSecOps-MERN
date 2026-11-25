# Observability (metrics, logs, traces)

Adapted from [iam-veeramalla/observability-zero-to-hero](https://github.com/iam-veeramalla/observability-zero-to-hero) for this MERN-on-EKS lab (2× `t3.medium` capacity).

## Course-day map

| Course day | Topic | In this repo |
|---|---|---|
| 1 | Concepts | This doc |
| 2–3 | Prometheus + Grafana + PromQL | `helm-values/prometheus-stack-values.yaml`, `scripts/eks-post-setup.sh` |
| 4 | Custom metrics / ServiceMonitor / alerts | `app/backend/metrics.js`, `k8s/observability/*` |
| 5 | Logging (EFK) | **Loki + Fluent Bit** (lighter than OpenSearch) — `helm-values/loki-values.yaml`, `fluent-bit-values.yaml` |
| 6–7 | Jaeger + OpenTelemetry | `helm-values/jaeger-values.yaml`, `otel-collector-values.yaml`, `app/backend/tracing.js` |

## Architecture

```
backend :3500 API  ──► frontend / ALB
backend :9090 /metrics ──► Prometheus (ServiceMonitor)
backend OTLP :4318 ──► otel-collector ──► Jaeger (traces only)
Fluent Bit ──► Loki ──► Grafana Explore
Prometheus / Loki ──► Grafana
Prometheus ──► Alertmanager (null receiver by default)
```

**Design choices:** prom-client for RED metrics; OTel for **traces only** (no duplicate metrics). Jaeger has **no public Ingress** — SSM port-forward only. Metrics scrape uses dedicated port **9090** (NetworkPolicy does not open API 3500 to `monitoring`).

## Capacity budgets (lab)

| Component | Requests | Limits | Notes |
|---|---|---|---|
| Prometheus | 200m / 512Mi | 500m / 1536Mi | 7d retention |
| Grafana | 50m / 128Mi | 300m / 512Mi | PVC 5Gi |
| Loki single-binary | 50m / 128Mi | 300m / 512Mi | PVC 10Gi, 7d retention |
| Fluent Bit | 20m / 32Mi | 100m / 128Mi | DaemonSet |
| Jaeger all-in-one | 50m / 128Mi | 300m / 512Mi | memory storage |
| OTel Collector | 50m / 128Mi | 250m / 256Mi | pinned `0.114.0` |

If the cluster OOMs, bump nodes to `t3.large` or shrink retention further.

## Prerequisites

1. EKS applied with **EBS CSI** addon ([`infra/eks/addons.tf`](../infra/eks/addons.tf)) for PVCs  
2. `kube-prometheus-stack` installed (creates ServiceMonitor CRDs)  
3. Prometheus values set `serviceMonitorSelectorNilUsesHelmValues: false` so `three-tier` ServiceMonitors are discovered  

## Install Prometheus + Grafana

```bash
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  --version 58.7.2 \
  -f helm-values/prometheus-stack-values.yaml
```

Set a strong `grafana.adminPassword` before install.

Grafana UI: `https://grafana.devops.example.com` ([`k8s/monitoring-ingress.yaml`](../k8s/monitoring-ingress.yaml)).

Prometheus in-cluster URL:

```
http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090
```

## Loki / Fluent Bit / Jaeger / OTel (GitOps)

After ArgoCD is up and the `gitops` branch has these files:

```bash
kubectl apply -f k8s/argocd-apps/observability-apps.yaml
```

Apps: `observability-crds`, `loki`, `fluent-bit`, `jaeger`, `otel-collector` (project `cluster-tools`).

### Jaeger access (no Ingress)

From jump/SSM with kubeconfig:

```bash
kubectl -n monitoring port-forward svc/jaeger 16686:16686
# open http://127.0.0.1:16686
```

### Backend instrumentation

- Metrics: `GET :9090/metrics` (`prom-client`) — ServiceMonitor [`k8s/observability/servicemonitor-backend.yaml`](../k8s/observability/servicemonitor-backend.yaml)  
- Traces: `node -r ./tracing.js` → OTLP HTTP to `otel-collector.monitoring.svc:4318`  
- Alerts: [`k8s/observability/prometheus-rules.yaml`](../k8s/observability/prometheus-rules.yaml)  
- NetPol: scrape **9090** from `monitoring` only; egress OTLP 4317/4318  

## Alertmanager

Default receiver is **`null`** (alerts fire in UI but go nowhere). Replace with Slack/email webhook in `helm-values/prometheus-stack-values.yaml` when ready.

## Dashboards

- Import Grafana ID `6417` (Kubernetes cluster)  
- Explore → Loki for `three-tier` / `monitoring` logs  
- Prometheus: `http_requests_total`, `http_request_duration_seconds`, `mongodb_ready`  

## Verify checklist

1. Prometheus → Status → Targets → `backend` / `three-tier` **UP**  
2. Grafana Explore → Loki → `{namespace="three-tier"}`  
3. Hit `/api/tasks` → Jaeger UI shows `backend` traces  
4. Optionally fire a test alert and confirm it appears in Alertmanager  
