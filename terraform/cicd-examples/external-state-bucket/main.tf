provider "aws" {
  region = var.region
}

resource "aws_s3_bucket" "terraform_state_bucket" {
  tags = {
    Name = "TerraformStateBucket"
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state_bucket" {
  bucket = aws_s3_bucket.terraform_state_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 encrypts new objects with SSE-S3 by default; declare it explicitly so the
# choice is visible and intentional for Terraform state.
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state_bucket" {
  bucket = aws_s3_bucket.terraform_state_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "terraform_state_bucket" {
  bucket = aws_s3_bucket.terraform_state_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Deny any request that does not use TLS.
resource "aws_s3_bucket_policy" "terraform_state_bucket" {
  bucket = aws_s3_bucket.terraform_state_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.terraform_state_bucket.arn,
          "${aws_s3_bucket.terraform_state_bucket.arn}/*",
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.terraform_state_bucket]
}

resource "aws_ssm_parameter" "state_bucket" {
  name  = "terraform_state_bucket"
  type  = "String"
  value = aws_s3_bucket.terraform_state_bucket.bucket
}
