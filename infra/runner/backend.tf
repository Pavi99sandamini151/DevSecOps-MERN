terraform {
  backend "s3" {
    bucket       = "YOUR_TFSTATE_BUCKET"
    region       = "us-east-1"
    key          = "infra/runner/terraform.tfstate"
    encrypt      = true
    use_lockfile = true # S3 native locking (replaces deprecated dynamodb_table)
  }

  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}
