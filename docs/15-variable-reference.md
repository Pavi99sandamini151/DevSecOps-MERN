# Variable and secret inventory

## GitLab CI/CD (9)

`AWS_ROLE_ARN`, `AWS_INFRA_ROLE_ARN`, `AWS_DEFAULT_REGION`, `AWS_ACCOUNT_ID`, `ECR_REPO_FRONTEND`, `ECR_REPO_BACKEND`, `SONAR_TOKEN`, `SONAR_HOST_URL`, `GITLAB_TOKEN`

## Terraform inputs

### infra/bootstrap (local state)
`region`, `state_bucket_name` (`YOUR_TFSTATE_BUCKET`) — locking uses S3 `use_lockfile`, not DynamoDB

### infra/dns
`region`, `parent_domain` (`example.com`), `subdomain` (`devops`)  
Creates zone `devops.example.com`, NS in parent, ACM for apex + wildcard.  
Outputs: `acm_certificate_arn`, `devops_zone_id`, `app_domain`  
Remote state key: `infra/dns/terraform.tfstate` in `YOUR_TFSTATE_BUCKET`

### infra/runner
`region`, `key-name`, `allowed_cidr`, `instance_type`, naming vars  
Remote state key: `infra/runner/terraform.tfstate` in `YOUR_TFSTATE_BUCKET`

### infra/oidc
`gitlab_namespace`, `gitlab_project`, `allowed_branches`, thumbprint  
Remote state key: `infra/oidc/terraform.tfstate` in `YOUR_TFSTATE_BUCKET`

### infra/eks
`cluster_name`, `vpc_cidr`, subnet CIDRs, node sizes, `kubernetes_version`  
Remote state key: `infra/eks/terraform.tfstate` in `YOUR_TFSTATE_BUCKET`

## Kubernetes Secrets

`mongo-sec` in `three-tier`: `mongodb-root-user`, `mongodb-root-password`, `mongodb-username`, `mongodb-password`

## Helm values

`helm-values/{alb-controller,kyverno,prometheus-stack,argocd,loki,fluent-bit,jaeger,otel-collector}-values.yaml`

## Rotation

- Rotate `SONAR_TOKEN` / `GITLAB_TOKEN` in GitLab UI + regenerate sources
- Rotate Mongo passwords via new Secret + roll Mongo/backend pods
- OIDC roles have no long-lived keys to rotate — revoke by deleting trust or role
