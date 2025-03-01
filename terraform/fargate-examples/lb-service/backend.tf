terraform {
  backend "s3" {
    key            = "lb-service/terraform.tfstate"
    encrypt        = true
  }
}
