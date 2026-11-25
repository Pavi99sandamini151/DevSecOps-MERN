output "state_bucket_name" {
  value = aws_s3_bucket.tfstate.id
}

output "state_bucket_arn" {
  value = aws_s3_bucket.tfstate.arn
}

output "backend_keys" {
  description = "State object keys used by each infra module"
  value = {
    runner = "infra/runner/terraform.tfstate"
    oidc   = "infra/oidc/terraform.tfstate"
    dns    = "infra/dns/terraform.tfstate"
    eks    = "infra/eks/terraform.tfstate"
  }
}
