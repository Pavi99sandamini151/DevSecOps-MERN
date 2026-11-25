# Security hardening checklist

Each item maps to defense-in-depth (C10) and/or shift-left fail-closed scanning (C4 / C9). Details: [`16-design-decisions.md`](./16-design-decisions.md).

## Platform / AWS

- [ ] IMDSv2 on runner and nodes (`http_tokens=required`) — C10
- [ ] CloudTrail multi-region + log validation — audit
- [ ] EKS control plane logs enabled — audit
- [ ] KMS encryption for Secrets in etcd — C10
- [ ] VPC Flow Logs → CloudWatch — forensics
- [ ] SonarQube SG restricted to your IP — C10
- [ ] WAF attached to ALB — C10
- [ ] Private EKS API; kubectl via SSM jump — C10

## Supply chain / CI

- [ ] ECR immutable + scan-on-push — C5
- [ ] Trivy `--exit-code 1` for CRITICAL,HIGH — C4 / C9
- [ ] OWASP DC + `npm audit --audit-level=high` — C4
- [ ] GitLab SAST + Secret Detection fail pipeline — C4 / C9
- [ ] Cosign keyless sign + Kyverno verify — C5 / C10
- [ ] OIDC only (no static AWS keys in GitLab) — C3
- [ ] Runner tagged `devsecops`; no shared runners — G2

## Kubernetes runtime

- [ ] Non-root securityContext (FE/BE); Bitnami MongoDB uid 1001 — C10
- [ ] NetworkPolicies applied — C10
- [ ] PDBs + replicas >= 2 for FE/BE — availability
- [ ] Dedicated ServiceAccounts, no ClusterRole bindings — C2
- [ ] ArgoCD/Grafana via HTTPS Ingress only — C10
- [ ] `prune: false` on ArgoCD apps — safe GitOps (C1)
- [ ] CORS origin restricted — app hardening
- [ ] MongoDB auth working — data plane
- [ ] `main` protected; CODEOWNERS present — process
