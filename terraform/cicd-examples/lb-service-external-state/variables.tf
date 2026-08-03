variable "region" {
  type        = string
  default     = "us-west-2"
  description = "AWS region you want to deploy to."
}

variable "environment" {
  type        = string
  default     = "development"
  description = "What environment this is associate with."
}

variable "container_image" {
  type        = string
  default     = "public.ecr.aws/docker/library/httpd:latest"
  description = "ref to container image"
}

variable "container_port" {
  type        = number
  default     = 80
  description = "container port"
}

variable "container_name" {
  type        = string
  default     = "ecsdemo-frontend"
  description = "container name"
}

variable "task_execution_role_arn" {
  type        = string
  default     = null
  description = "ARN of a pre-provisioned ECS task execution role. A role is created when omitted."
}

variable "task_role_arn" {
  type        = string
  default     = null
  description = "ARN of a pre-provisioned ECS task role. A role is created when omitted."
}

variable "codedeploy_service_role_arn" {
  type        = string
  default     = null
  description = "ARN of a pre-provisioned CodeDeploy service role. A role is created when omitted."
}
