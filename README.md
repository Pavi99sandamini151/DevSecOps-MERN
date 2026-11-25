# End-to-End DevSecOps on MERN Stack — GitLab CI Edition

Private EKS + GitLab CI/CD (OIDC) + ArgoCD GitOps + ECR + SonarQube + Trivy + Cosign + Kyverno + ALB/WAF + Prometheus/Grafana.

Based on [AmanPathak-DevOps/End-to-End-Kubernetes-Three-Tier-DevSecOps-Project](https://github.com/AmanPathak-DevOps/End-to-End-Kubernetes-Three-Tier-DevSecOps-Project), rebuilt for **GitLab CI** instead of Jenkins.

## Interview points

- Designed and implemented an end-to-end DevSecOps platform using Terraform, Kubernetes, and GitOps practices.
- Automated AWS provisioning with Terraform, including VPC, private EKS cluster, node groups, and jump server.
- Built GitLab CI/CD pipelines integrating SonarQube quality gates, OWASP dependency checks, Trivy security scanning, Docker image publishing, and ECR.
- Implemented GitOps deployments with ArgoCD, AWS Load Balancer Controller, Kubernetes Ingress, and Route53 for traffic routing.
- Configured Prometheus and Grafana dashboards for Kubernetes cluster and application monitoring.

## Development guide

Day-to-day work — local app, `main` vs `gitops`, and where a change has to land — is in [`docs/17-development-guide.md`](docs/17-development-guide.md).

## Learning the repo (beginners)

Every CI file, Dockerfile, operator script, and key Terraform/K8s manifest starts with a
**BEGINNER MAP / WHAT / WHY** comment block — read the file top-to-bottom like a lesson.

| Start here | What you will learn |
|---|---|
| [`docs/11-ci-pipelines.md`](docs/11-ci-pipelines.md) | Pipeline stages in plain English |
| [`docs/16-design-decisions.md`](docs/16-design-decisions.md) | Why each major choice (practices C1–C10) |
| `.gitlab-ci.yml` + `ci/*.yml` | Job-by-job teaching comments |
| `app/*/Dockerfile` | Multi-stage builds, non-root uid 1000 |
| `scripts/*.sh` | Runner register + EKS post-setup steps |

App source (`index.js`, React) stays free of CI commentary on purpose.

## Quick start

Follow `docs/` in order:

0. [Architecture](docs/00-architecture.md)
1. [Prerequisites](docs/01-prerequisites.md)
2. [Manual bootstrap](docs/02-bootstrap-manual.md) ← required before any CI
3. [Runner setup](docs/03-runner-setup.md)
4. [OIDC AWS setup](docs/04-oidc-aws-setup.md)
5. [GitLab variables](docs/05-gitlab-variables.md)
6. [EKS infra](docs/06-eks-infrastructure.md)
7. [Route53 + ACM](docs/07-route53-acm.md)
8. [EKS post-setup](docs/08-eks-post-setup.md)
9. [ArgoCD apps](docs/09-argocd-applications.md)
10. [ECR](docs/10-ecr-setup.md)
11. [CI pipelines](docs/11-ci-pipelines.md)
12. [Monitoring](docs/12-monitoring.md)
13. [Security checklist](docs/13-security-hardening.md)
14. [Troubleshooting](docs/14-troubleshooting.md)
15. [Variable reference](docs/15-variable-reference.md)
16. [Design decisions (why + practice)](docs/16-design-decisions.md)
17. [Development guide](docs/17-development-guide.md)

## Repo layout

```
.gitlab-ci.yml
infra/
  bootstrap/        # Shared S3 tfstate bucket + S3 native lockfiles (local state)
  runner/           # GitLab Runner EC2 + SonarQube
  oidc/             # GitLab → AWS OIDC (app + infra roles)
  dns/              # devops.example.com zone + ACM (NS from example.com)
  eks/              # VPC, private EKS, ECR, KMS, WAF, CloudTrail
app/{frontend,backend}
k8s/                # Deployments, netpols, PDBs, Kyverno, ArgoCD apps
ci/                 # infra / frontend / backend pipelines
helm-values/
docs/
scripts/
```

## Security highlights

- OIDC federation (no `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` in GitLab)
- IMDSv2, KMS etcd encryption, CloudTrail, VPC Flow Logs
- Immutable ECR tags + scan-on-push + Trivy + keyless Cosign + Kyverno
- NetworkPolicies, non-root pods, PDBs, restricted CORS, WAFv2 on ALB
