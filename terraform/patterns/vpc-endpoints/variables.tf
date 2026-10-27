variable "aws_region" {
  description = "AWS Region in which to deploy the example."
  type        = string
  default     = "us-west-2"
}

variable "name" {
  description = "Name prefix for resources. Change this to deploy another copy in the same account and Region."
  type        = string
  default     = "ecsdemo-vpc-endpoints"
}
