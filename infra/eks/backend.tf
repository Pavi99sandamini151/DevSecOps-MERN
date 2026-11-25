terraform {
  backend "s3" {
    bucket       = "YOUR_TFSTATE_BUCKET"
    region       = "us-east-1"
    key          = "infra/eks/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }

  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.0"
    }
  }
}
