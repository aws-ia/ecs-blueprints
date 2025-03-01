terraform {
  backend "s3" {
    key            = "container-registry/terraform.tfstate"
    encrypt        = true
  }
}
