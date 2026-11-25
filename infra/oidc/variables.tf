variable "region" {
  type    = string
  default = "us-east-1"
}

variable "gitlab_namespace" {
  description = "GitLab group or username that owns the project"
  type        = string
}

variable "gitlab_project" {
  description = "GitLab project path name"
  type        = string
  default     = "devsecops-mern-eks"
}

variable "gitlab_oidc_url" {
  type    = string
  default = "https://gitlab.com"
}

variable "gitlab_oidc_audience" {
  type    = string
  default = "https://gitlab.com"
}

# GitLab.com TLS certificate thumbprint (update if GitLab rotates certs)
variable "gitlab_oidc_thumbprint" {
  type    = string
  default = "b3dd7606d2cd9e21a599f41ae67bb1e6c18062d0"
}

variable "allowed_branches" {
  type    = list(string)
  default = ["main"]
}
