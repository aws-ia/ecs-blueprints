terraform {
  backend "s3" {
    key            = "state-management/terraform.tfstate"
    encrypt        = true
  }
}
