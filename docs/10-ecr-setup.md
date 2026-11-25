# ECR repositories and publish workflow

## Why immutable tags + scan-on-push

- **Immutable:** Prevents silent overwrite of a tag that Kyverno / prod already trusts (C5).
- **Scan-on-push:** AWS-native baseline; CI Trivy still fails the pipeline on CRITICAL/HIGH (C4 / C9).

## Terraform (`infra/eks/ecr.tf`)

- Repos: `frontend`, `backend`
- `image_tag_mutability = IMMUTABLE`
- `scan_on_push = true`
- Lifecycle: keep last 10 images
- Optional registry enhanced scanning (Inspector)

## CI publish sequence

1. `docker build -t $ECR_REPO_FRONTEND app/frontend`
2. `aws ecr get-login-password | docker login ...` (OIDC app role — C3)
3. Tag with `$CI_PIPELINE_IID` (never `latest`) — C5
4. `docker push`
5. `docker rmi` local cleanup
6. Cosign keyless sign — C5
7. Trivy image scan from ECR with `--exit-code 1` — C4 / C9

Kyverno on the cluster admits only signed images (C10).

## Verify

```bash
aws ecr describe-repositories
aws ecr list-images --repository-name frontend
aws ecr describe-image-scan-findings --repository-name frontend --image-id imageTag=42
```
