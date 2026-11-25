# OIDC federation (GitLab → AWS)

Terraform module: [`infra/oidc/`](../infra/oidc/)

## Why

Static `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` in GitLab are a high-risk secret (rarely rotated, broad blast radius if leaked). OIDC issues a short-lived JWT per job; AWS STS exchanges it for temporary credentials.

**Practice:** C3 (OIDC federation), C2 (least privilege via two roles).

## Two roles (C2 / C3)

| Role | Variable | Used by | Permissions |
|---|---|---|---|
| `gitlab-ci-app-role` | `AWS_ROLE_ARN` | frontend/backend pipelines | ECR push, EKS describe, S3 read |
| `gitlab-ci-infra-role` | `AWS_INFRA_ROLE_ARN` | `ci/infra.gitlab-ci.yml` | EKS/VPC/IAM/KMS/WAF/ECR manage |

Trust condition: `gitlab.com:sub` = `project_path:YOUR_GITLAB_NAMESPACE/devsecops-mern-eks:ref_type:branch:ref:main`

**Why `ref:main` only:** Feature branches / forks must not assume production roles.

## Job pattern

```yaml
id_tokens:
  AWS_JWT:
    aud: https://gitlab.com
before_script:
  - aws sts assume-role-with-web-identity --role-arn $AWS_ROLE_ARN --web-identity-token $AWS_JWT ...
```

Audience (`aud`) must match the IAM OIDC provider configuration.

## Verify

Add a test job that prints `aws sts get-caller-identity` after assume.
