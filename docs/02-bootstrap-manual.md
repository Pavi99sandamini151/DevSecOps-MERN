# Step 0 — Manual bootstrap (before CI exists)

Resolves Conflicts C2 and Gaps G1/G12. **Never** try to create OIDC roles via GitLab CI on day one.

## 1. Create shared Terraform state backend

```bash
cd infra/bootstrap
terraform init
terraform apply
cd ../..
```

Creates (via [`infra/bootstrap/`](../infra/bootstrap/) — **local** state):

- `s3://YOUR_TFSTATE_BUCKET` — one shared bucket for all remote states
  - keys: `infra/runner|oidc|dns|eks/terraform.tfstate`
  - locking via S3 native lockfiles (`use_lockfile = true`) — no DynamoDB table

Bucket hardening: versioning ON, SSE AES256, public access blocked.

Do **not** commit `infra/bootstrap/terraform.tfstate` (gitignored).

## 2. Apply infra/runner (local)

```bash
# Edit infra/runner/terraform.tfvars first (key-name, allowed_cidr)
cd infra/runner
terraform init
terraform apply
cd ../..
```

Note outputs: `runner_public_ip`, `sonarqube_url`, `runner_instance_id`.

## 3. Apply infra/oidc (local)

```bash
# infra/oidc/terraform.tfvars already set to gitlab_namespace = "YOUR_GITLAB_NAMESPACE"
cd infra/oidc
terraform init
terraform apply
terraform output
cd ../..
```

Save:

- `gitlab_ci_app_role_arn` → GitLab `AWS_ROLE_ARN`
- `gitlab_ci_infra_role_arn` → GitLab `AWS_INFRA_ROLE_ARN`

## 4. Apply infra/dns (delegated devops.example.com zone)

Requires existing Route53 zone `example.com` in the account. See [docs/07-route53-acm.md](07-route53-acm.md).

```bash
cd infra/dns
terraform init
terraform apply
terraform output acm_certificate_arn   # paste into k8s/*ingress*.yaml later
cd ../..
```

## 5. Register GitLab Runner (Docker executor)

1. GitLab → Settings → CI/CD → Runners → New project runner → Linux
2. Tag: `devsecops`
3. SSM into runner EC2 and run:

```bash
export RUNNER_AUTH_TOKEN=glrt-...
./scripts/register-runner.sh
```

Verify green runner in GitLab UI.

## 6. Expected time

~20–30 minutes (ACM DNS validation may add a few minutes).
