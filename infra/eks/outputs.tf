output "cluster_name" {
  value = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.main.endpoint
}

output "cluster_oidc_issuer" {
  value = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

output "cluster_oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.eks.arn
}

output "jump_instance_id" {
  value = aws_instance.jump.id
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "frontend_repository_url" {
  value = aws_ecr_repository.frontend.repository_url
}

output "backend_repository_url" {
  value = aws_ecr_repository.backend.repository_url
}

output "waf_web_acl_arn" {
  description = "Use in Ingress annotation alb.ingress.kubernetes.io/wafv2-acl-arn"
  value       = aws_wafv2_web_acl.alb.arn
}

output "kms_key_arn" {
  value = aws_kms_key.eks.arn
}
