provider "aws" {
  region = var.region
}

resource "aws_s3_bucket" "terraform_state_bucket" {

  acl    = "private"  # Set the bucket ACL as per your security requirements

  versioning {
    enabled = true  # Enable versioning for Terraform state file history
  }

  tags = {
    Name        = "TerraformStateBucket"
  }
}

resource "aws_ssm_parameter" "state_bucket" {
  name  = "terraform_state_bucket"
  type  = "String"
  value = aws_s3_bucket.terraform_state_bucket.bucket
}
