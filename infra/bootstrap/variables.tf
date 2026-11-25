variable "region" {
  type    = string
  default = "us-east-1"
}

variable "state_bucket_name" {
  description = "Shared S3 bucket for all infra module remote states"
  type        = string
  default     = "YOUR_TFSTATE_BUCKET"
}
