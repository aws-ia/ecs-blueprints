terraform {
  # S3 native state locking (use_lockfile in the backend block) requires >= 1.11
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.56"
    }
  }
}
