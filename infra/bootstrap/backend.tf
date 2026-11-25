# Local backend only — chicken-and-egg: this module creates the remote state bucket.
# Do not commit terraform.tfstate (covered by root .gitignore).
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }

  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}
