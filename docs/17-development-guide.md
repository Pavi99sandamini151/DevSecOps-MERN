# Development guide

Day-to-day work in this repo. Platform bring-up (AWS account, runner, EKS, DNS) stays in [`00-architecture.md`](./00-architecture.md) through [`16-design-decisions.md`](./16-design-decisions.md). Read those in order the first time you stand the platform up.

## What you are changing

| You want to… | Edit | What picks it up |
|---|---|---|
| API behavior | `app/backend/` | Backend pipeline on `main`, then a new image on `gitops` |
| UI behavior | `app/frontend/` | Frontend pipeline on `main`, then a new image on `gitops` |
| How pods, ingress, or policies run | `k8s/` | ArgoCD, which watches **`gitops`**, not `main` |
| Cluster, VPC, ECR, WAF | `infra/eks/` | Manual Terraform jobs in `ci/infra.gitlab-ci.yml` |
| Runner, OIDC, DNS, state bucket | `infra/runner`, `infra/oidc`, `infra/dns`, `infra/bootstrap` | Local `terraform apply` (not the CI pipeline) |
| Scan or release behavior | `.gitlab-ci.yml`, `ci/` | The next pipeline on `main` |

## Fill these in before the first real apply

The tree is a template. These placeholders are safe to commit. Replace them in your own copy, and do not commit the real values back to a public remote.

| Placeholder | Where | Replace with |
|---|---|---|
| `YOUR_GITLAB_NAMESPACE` | `infra/oidc/terraform.tfvars`, `k8s/argocd-apps/`, `k8s/kyverno-policies/image-verify-policy.yaml`, `CODEOWNERS`, `scripts/eks-post-setup.sh` | GitLab group or username |
| `YOUR_TFSTATE_BUCKET` | `infra/*/backend.tf`, `infra/bootstrap/terraform.tfvars`, IAM policies | Globally unique S3 bucket name |
| `example.com` / `devops.example.com` | `infra/dns/terraform.tfvars`, ingress hosts, app CORS | Your parent zone and app hostname |
| `ACCOUNT_ID` / `REPLACE_ACM_CERT_ARN` | `k8s/*ingress*.yaml`, image refs on `main` | Account id and ACM ARN after `infra/dns` apply |
| `203.0.113.10/32` | `infra/runner/terraform.tfvars` | Your public IP for SonarQube |
| `CHANGE_ME_*` | `k8s/database/secret.yaml` | Real Mongo passwords, or create the Secret with `scripts/eks-post-setup.sh` |

`terraform.tfvars` is tracked because CI runs `terraform plan -var-file=terraform.tfvars`. Put machine-specific overrides in `*.auto.tfvars` or `*.tfvars.local` (both gitignored). Never commit `.env`, `*.pem`, kubeconfig, or `.aws/`.

## Run the app on your laptop

The API listens on port **3500**. The UI dev server listens on port **3000**. Mongo is not started by this repo.

```bash
docker run -d --name todo-mongo -p 27017:27017 mongo:7

cd app/backend
npm ci
export MONGO_CONN_STR='mongodb://127.0.0.1:27017/todo'
export ALLOWED_ORIGIN='http://localhost:3000'
node index.js
```

In a second terminal:

```bash
cd app/frontend
npm ci
export REACT_APP_BACKEND_URL='http://localhost:3500/api/tasks'
npm start
```

Checks:

- `curl -s localhost:3500/healthz` returns `Healthy`
- `curl -s localhost:3500/ready` returns `Ready` only after Mongo is connected
- Metrics are on port `9090` (`/metrics`)

`REACT_APP_BACKEND_URL` is read when Create React App builds. Set it before `npm start` and before `npm run build`. A value added later on the Kubernetes pod does not change an image that was already built.

The production API image runs `node -r ./tracing.js index.js`. Skip that locally unless an OpenTelemetry collector is reachable. CORS rejects browser origins other than `ALLOWED_ORIGIN` (default `https://devops.example.com`).

## Branches

| Branch | Who writes it | Who reads it |
|---|---|---|
| `main` | You, through merge requests | GitLab CI |
| `gitops` | CI, when it rewrites the image tag | ArgoCD |

Create `gitops` once with `./scripts/init-gitops-branch.sh`.

On `main`, Deployments still say `ACCOUNT_ID…:IMAGE_TAG_PLACEHOLDER`. That is intentional. The backend and frontend `update-manifest` jobs check out `gitops` and replace only the image line, then push with `[skip ci]`. ArgoCD syncs that branch.

A change to probes, env, ingress, or policies on `main` does **not** roll out by itself. Copy those manifest edits onto `gitops` as well. CI will not do that for you. It only rewrites the image reference.

Do not push app commits straight to `gitops`. Do not remove `[skip ci]` from the manifest commit. Without it, the push starts another pipeline, which commits again, forever.

## How a normal app change ships

1. Branch from `main` and open a merge request.
2. Pipeline path filters run the frontend jobs for `app/frontend/**` and the backend jobs for `app/backend/**`.
3. On `main`, the chain is SonarQube and its quality gate, OWASP dependency check plus `npm audit`, Trivy filesystem scan, Docker build, ECR push tagged with `$CI_PIPELINE_IID`, Trivy image scan, keyless Cosign, then the `gitops` image update.
4. ArgoCD rolls the new tag into namespace `three-tier`.

Secret detection and Semgrep run on `main` and on merge requests. Scanners use `allow_failure: false` and the `devsecops` runner tag. Infra jobs are not created unless files under `infra/` change or the pipeline variable `RUN_INFRA` is true, so an app push is not stuck behind a manual Terraform button.

Details and the failure modes already hit in this repo: [`11-ci-pipelines.md`](./11-ci-pipelines.md).

## Terraform while developing

CI covers **`infra/eks` only**, and `tf-init`, `tf-apply`, and `tf-destroy` are manual. `tf-validate` and `tf-plan` run after init when infra files change.

```bash
terraform -chdir=infra/eks init
terraform -chdir=infra/eks plan -var-file=terraform.tfvars
```

Apply bootstrap, the runner, OIDC, and DNS from your laptop, in the order in [`02-bootstrap-manual.md`](./02-bootstrap-manual.md). Each stack has its own backend key in `YOUR_TFSTATE_BUCKET`. Run `terraform init` again if `.terraform/` is missing. Provider binaries are gitignored.

## Cluster manifests

ArgoCD app order is service accounts, network policies, database, backend, frontend, ingress, then PDBs. Observability charts live in `k8s/argocd-apps/observability-apps.yaml`. Sync policy is `selfHeal: true` and `prune: false`. See [`09-argocd-applications.md`](./09-argocd-applications.md).

Mongo credentials belong in the `mongo-sec` Secret, not in Deployment YAML. The backend reads `MONGO_CONN_STR`, `MONGO_USERNAME`, and `MONGO_PASSWORD`.

## Where to read next

| Question | Doc |
|---|---|
| Why a control exists | [`16-design-decisions.md`](./16-design-decisions.md) |
| Pipeline stages | [`11-ci-pipelines.md`](./11-ci-pipelines.md) |
| CI variable names | [`05-gitlab-variables.md`](./05-gitlab-variables.md) and [`15-variable-reference.md`](./15-variable-reference.md) |
| Something failed | [`14-troubleshooting.md`](./14-troubleshooting.md) |
