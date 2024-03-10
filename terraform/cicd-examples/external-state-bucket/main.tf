provider "aws" {
  region = var.region
}

resource "aws_s3_bucket" "terraform_state_bucket" {
  tags = {
    Name = "TerraformStateBucket"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state_bucket" {
  bucket = aws_s3_bucket.terraform_state_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_ssm_parameter" "state_bucket" {
  name  = "terraform_state_bucket"
  type  = "String"
  value = aws_s3_bucket.terraform_state_bucket.bucket
}
