terraform {
  backend "s3" {
    bucket         = "cleanlink-portal-api-terraform-state-eu-west-2"
    region         = "eu-west-2"
    dynamodb_table = "cleanlink-portal-api-terraform-state-eu-west-2"
    key            = "portal-api/terraform.tfstate"
    encrypt        = true
  }
}
