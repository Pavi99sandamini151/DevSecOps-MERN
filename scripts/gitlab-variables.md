# GitLab CI/CD Variables Checklist

Set these in **Settings → CI/CD → Variables**. No static AWS access keys.

| Variable | Masked | Protected | Example / Source |
|---|---|---|---|
| `AWS_ROLE_ARN` | No | No | `terraform -chdir=infra/oidc output -raw gitlab_ci_app_role_arn` |
| `AWS_INFRA_ROLE_ARN` | No | No | `terraform -chdir=infra/oidc output -raw gitlab_ci_infra_role_arn` |
| `AWS_DEFAULT_REGION` | No | No | `us-east-1` |
| `AWS_ACCOUNT_ID` | No | No | `aws sts get-caller-identity --query Account --output text` |
| `ECR_REPO_FRONTEND` | No | No | `frontend` |
| `ECR_REPO_BACKEND` | No | No | `backend` |
| `SONAR_TOKEN` | **Yes** | **Yes** | SonarQube → My Account → Security → Generate Tokens |
| `SONAR_HOST_URL` | No | No | `http://<runner-public-ip>:9000` |
| `GITLAB_TOKEN` | **Yes** | **Yes** | Project Access Token, scope `write_repository` (pushes to `gitops`) |

## Project Access Token (GITLAB_TOKEN)

1. Settings → Access Tokens → Add new token
2. Role: Maintainer
3. Scopes: `write_repository` (+ `read_repository` if ArgoCD shares the token)
4. Mark CI variable Masked + Protected

## Protected branches

1. Protect `main` — Maintainers may merge; no direct push; require 1 approval
2. Protect `gitops` — allow Maintainer + CI token push (no MR required)
3. Settings → CI/CD → Token Access → Limit CI_JOB_TOKEN to this project

## Runner

1. Settings → CI/CD → Runners → New project runner → Linux → copy auth token
2. Tag: `devsecops`
3. Run `scripts/register-runner.sh` on the runner EC2
