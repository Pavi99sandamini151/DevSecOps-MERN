# GitLab CI/CD variables

See also `scripts/gitlab-variables.md` and [`16-design-decisions.md`](./16-design-decisions.md).

## Why these variables (and not AWS keys)

| Variable | Masked | Protected | Why |
|---|---|---|---|
| `AWS_ROLE_ARN` | No | No | App jobs assume this role via OIDC (C3) |
| `AWS_INFRA_ROLE_ARN` | No | No | Terraform jobs — broader, separate role (C2) |
| `AWS_DEFAULT_REGION` | No | No | Single-region lab default |
| `AWS_ACCOUNT_ID` | No | No | Build ECR URIs |
| `ECR_REPO_FRONTEND` / `ECR_REPO_BACKEND` | No | No | Repo names for push/sign |
| `SONAR_TOKEN` | Yes | Yes | Authenticate scanner / QG API |
| `SONAR_HOST_URL` | No | No | Human/docs URL (`http://<runner-ip>:9000`). CI scanner jobs use host-local `127.0.0.1` instead |
| `GITLAB_TOKEN` | Yes | Yes | CI pushes image tags to `gitops` (C1 / C6) |

**Do not set** `AWS_ACCESS_KEY_ID` or `AWS_SECRET_ACCESS_KEY` — use OIDC (C3).

Optional: `RUN_INFRA=true` on **Run pipeline** to create Terraform jobs without an infra file change (C7 / C8).

## Branch protection

- `main`: MR-only, 1 approver, CODEOWNERS — protects production CI roles trust
- `gitops`: CI bot may push; ArgoCD watches this branch (C1)
- Limit `CI_JOB_TOKEN` to this project
