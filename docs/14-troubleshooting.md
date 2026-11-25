# Troubleshooting

Design rationale: [`16-design-decisions.md`](./16-design-decisions.md).

| Symptom | Likely cause | Fix |
|---|---|---|
| App pipeline stuck on manual `tf-init` | infra jobs always created | infra rules only on `infra/**` or `RUN_INFRA=true` (C7/C8) |
| Frontend Trivy finds backend CVEs | include-level `APP_DIR` collision | keep vars under `.frontend_rules` / `.backend_rules` |
| `sonar-scanner: not found` | host tool invisible in Docker job | use scanner image / `docker run` (G2) |
| Sonar `Connect timed out` to public IP | SG / hairpin from job net | scan via `--network host` → `127.0.0.1:9000` |
| `client version 1.43 is too old` | `docker:24` vs host API 1.44+ | use `docker:27` |
| Sonar `Fail to create .scannerwork` | scanner user cannot write bind mount | `-Dsonar.working.directory=/tmp/.scannerwork` + `-u root` |
| OWASP 30m timeout / NVD URL column error | DC 10.x + cold NVD DB | DC 12.x, 60m timeout, `.ci-cache/owasp` |
| CI git push 403 | protected `main` | push to `gitops` |
| terraform init no bucket | state not bootstrapped | `cd infra/bootstrap && terraform init && terraform apply` |
| cannot connect to Docker daemon | shell executor | use Docker executor (G2) |
| AssumeRoleWithWebIdentity 403 | trust / OIDC missing | re-apply infra/oidc; check `gitlab.com:sub` |
| `aws: not found` / `terraform: not found` in tf-* | job used runner default image | infra jobs use `ubuntu:24.04` + cached official binaries |
| `Terraform has no command named "sh"` | image ENTRYPOINT is `terraform` | do not use raw `hashicorp/terraform` as job image without clearing entrypoint |
| `XML_SetAllocTrackerActivationThreshold` / pyexpat | alpine `aws-cli` vs terraform image libs | use Ubuntu + official AWS CLI v2 (current `ci/infra.gitlab-ci.yml`) |
| Unsupported Terraform Core version (>= 1.10.0) | CI `TF_VERSION` too old for `use_lockfile` | set `TF_VERSION` to `1.10.5`+ in `ci/infra.gitlab-ci.yml` |
| `inspector2:Enable` AccessDenied on ECR enhanced scan | infra OIDC role missing Inspector | re-apply `infra/oidc` (policy includes `inspector2:*` enable) |
| `iam:TagInstanceProfile` AccessDenied | infra OIDC IAM actions incomplete | re-apply `infra/oidc` |
| unsupported Kubernetes version 1.29 | EKS no longer creates 1.29 clusters | set `kubernetes_version = "1.32"` in `infra/eks/terraform.tfvars` |
| `sast is used for configuration only` / exit 1 | parent `sast` job was given run rules | set `sast: rules: [{when: never}]`; configure `semgrep-sast` instead |
| kubectl timeout from laptop | private EKS | use jump server SSM |
| kubectl `dial tcp :443 i/o timeout` on jump | cluster SG missing jump→443 | apply `aws_security_group_rule.cluster_api_from_jump` in `infra/eks` |
| kubectl asks for credentials on jump | jump role not in EKS access entries | `aws_eks_access_entry.jump` + AmazonEKSClusterAdminPolicy; auth mode `API_AND_CONFIG_MAP` |
| Mongo CrashLoop | wrong Bitnami env/secret | check `mongo-sec` keys |
| Mongo `ErrImagePull` `bitnami/mongodb:7.0` not found | Bitnami retired free Hub tags | use `bitnamilegacy/mongodb:7.0` (see `k8s/database/deployment.yaml`) |
| Kyverno `401 Unauthorized` on ECR during verify-image-signatures | Kyverno pod has no ECR creds (node IAM ≠ admission pulls) | run `./scripts/kyverno-ecr-access.sh` on jump; ensure policy `imagePullSecrets: [ecr-pull-secret]` |
| Kyverno `ACCOUNT_ID` / `IMAGE_TAG_PLACEHOLDER` denied | ArgoCD syncing `main` placeholders | set Application targetRevision to `gitops` |
| Grafana no data | wrong Prometheus URL | use `prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090` |
| ServiceMonitor never scraped | Helm selector too strict | `serviceMonitorSelectorNilUsesHelmValues: false` in prometheus-stack values |
| Loki/Grafana PVC Pending | no EBS CSI / StorageClass | apply EKS addon + `k8s/observability/storageclass-gp3.yaml` |
| Jaeger UI unreachable | no public Ingress by design | `kubectl -n monitoring port-forward svc/jaeger 16686:16686` via SSM |
| Trivy exits 1 | CRITICAL/HIGH CVE | update base image or justified `.trivyignore` |
| Cosign fails | missing `id_tokens` | ensure job-level `AWS_JWT` |
| Quality gate NONE | async analysis | polling loop (G9) already in pipeline |
| ALB not created | controller/IAM | check controller logs + Ingress events |
