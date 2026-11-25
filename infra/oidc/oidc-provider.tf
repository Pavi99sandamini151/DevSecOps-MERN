# =============================================================================
# GitLab → AWS OIDC provider
# =============================================================================
# BEGINNER MAP
#   Instead of saving AWS access keys in GitLab CI variables (they leak easily),
#   we teach AWS to trust GitLab's short-lived JWTs.
#
#   Flow every CI job uses:
#     1) GitLab mints a JWT for this job (id_tokens: AWS_JWT in ci/*.yml)
#     2) Job calls sts:AssumeRoleWithWebIdentity with that JWT
#     3) AWS checks: trusted OIDC provider? audience ok? subject = main branch?
#     4) Job gets temporary keys that expire in ~1 hour (C3)
#
# WHY thumbprint + audience?
#   They pin "this really is gitlab.com" so a fake issuer cannot assume our roles.
# =============================================================================
resource "aws_iam_openid_connect_provider" "gitlab" {
  url             = var.gitlab_oidc_url
  client_id_list  = [var.gitlab_oidc_audience]
  thumbprint_list = [var.gitlab_oidc_thumbprint]

  tags = {
    Name = "gitlab-oidc-provider"
  }
}

locals {
  project_path = "project_path:${var.gitlab_namespace}/${var.gitlab_project}"
  # Only jobs on the main branch of THIS project may assume the roles (C2)
  sub_main = "${local.project_path}:ref_type:branch:ref:main"
}
