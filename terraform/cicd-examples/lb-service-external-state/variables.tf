variable region {
  type        = string
  default     = "us-west-2"
  description = "AWS region you want to deploy to."
}

variable environment {
  type        = string
  default     = "development"
  description = "What environment this is associate with."
}

variable "container_image" {
  type = string
  default = "public.ecr.aws/docker/library/httpd:latest"
  description = "ref to container image"
}

variable "container_port" {
  type = number
  default = 80
  description = "container port"
}

variable "container_name" {
  type = string
  default = "ecsdemo-frontend"
  description = "container name"
}
