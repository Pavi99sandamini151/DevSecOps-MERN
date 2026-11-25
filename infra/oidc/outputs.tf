output "gitlab_oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.gitlab.arn
}

output "gitlab_ci_app_role_arn" {
  description = "Set as GitLab CI/CD variable AWS_ROLE_ARN"
  value       = aws_iam_role.gitlab_ci_app.arn
}

output "gitlab_ci_infra_role_arn" {
  description = "Set as GitLab CI/CD variable AWS_INFRA_ROLE_ARN"
  value       = aws_iam_role.gitlab_ci_infra.arn
}
