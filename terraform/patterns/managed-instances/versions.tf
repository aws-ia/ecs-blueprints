terraform {
  required_version = ">= 1.5.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.56"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.14"
    }
  }
}
