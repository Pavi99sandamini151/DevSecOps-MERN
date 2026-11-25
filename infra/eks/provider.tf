provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "devsecops-mern-eks"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
