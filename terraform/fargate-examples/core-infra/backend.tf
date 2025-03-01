terraform {
  backend "s3" {
    key     = "core-infra/terraform.tfstate"
    encrypt = true
  }
}
