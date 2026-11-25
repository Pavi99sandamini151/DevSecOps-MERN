variable "region" {
  type    = string
  default = "us-east-1"
}

variable "vpc-name" {
  type = string
}

variable "igw-name" {
  type = string
}

variable "rt-name" {
  type = string
}

variable "subnet-name" {
  type = string
}

variable "sg-name" {
  type = string
}

variable "instance-name" {
  type = string
}

variable "key-name" {
  description = "Optional EC2 key pair. Leave empty to use SSM Session Manager only (recommended)."
  type        = string
  default     = ""
}

variable "iam-role" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.xlarge"
}

variable "allowed_cidr" {
  description = "CIDR allowed to reach SonarQube (port 9000) and SSH. Use your IP/VPN, never 0.0.0.0/0 for SonarQube."
  type        = string
}

variable "ssh_allowed_cidr" {
  description = "CIDR allowed for SSH. Prefer SSM Session Manager; keep SSH locked down."
  type        = string
  default     = null
}
