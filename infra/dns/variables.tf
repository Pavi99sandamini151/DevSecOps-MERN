variable "region" {
  type    = string
  default = "us-east-1"
}

variable "parent_domain" {
  description = "Existing Route53 hosted zone (already in AWS account)"
  type        = string
  default     = "example.com"
}

variable "subdomain" {
  description = "Delegated subdomain label under parent_domain"
  type        = string
  default     = "devops"
}
