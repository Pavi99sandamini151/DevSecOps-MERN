output "app_domain" {
  description = "Primary app hostname"
  value       = local.app_domain
}

output "argocd_host" {
  value = "argocd.${local.app_domain}"
}

output "grafana_host" {
  value = "grafana.${local.app_domain}"
}

output "parent_zone_id" {
  value = data.aws_route53_zone.parent.zone_id
}

output "devops_zone_id" {
  description = "Use this zone for ALB A-alias records after Ingress creates the load balancer"
  value       = aws_route53_zone.devops.zone_id
}

output "devops_name_servers" {
  value = aws_route53_zone.devops.name_servers
}

output "acm_certificate_arn" {
  description = "Paste into k8s Ingress alb.ingress.kubernetes.io/certificate-arn"
  value       = aws_acm_certificate_validation.main.certificate_arn
}
