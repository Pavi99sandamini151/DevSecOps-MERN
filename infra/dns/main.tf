locals {
  app_domain = "${var.subdomain}.${var.parent_domain}" # devops.example.com
}

# Existing apex zone — do not create/manage example.com itself
data "aws_route53_zone" "parent" {
  name         = var.parent_domain
  private_zone = false
}

# Dedicated hosted zone for the DevOps platform
resource "aws_route53_zone" "devops" {
  name = local.app_domain

  tags = {
    Name      = local.app_domain
    Purpose   = "devsecops-platform-dns"
    ManagedBy = "terraform"
  }
}

# NS delegation: example.com → devops.example.com zone
resource "aws_route53_record" "devops_ns" {
  zone_id = data.aws_route53_zone.parent.zone_id
  name    = local.app_domain
  type    = "NS"
  ttl     = 300
  records = aws_route53_zone.devops.name_servers
}

# TLS cert for apex subdomain + wildcard (argocd/grafana hosts)
resource "aws_acm_certificate" "main" {
  domain_name               = local.app_domain
  subject_alternative_names = ["*.${local.app_domain}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name      = local.app_domain
    ManagedBy = "terraform"
  }
}

# Validation CNAMEs live in the CHILD zone
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.devops.zone_id
}

resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}
