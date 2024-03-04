variable "region" {
  type        = string
  default     = "us-west-2"
  description = "AWS region you want to deploy to."
}

variable "s3_bucket" {
  type        = string
  default     = "terraform-20240118200828358000000001"
  description = "s3 bucket"
}
