variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "core_stack_name" {
  description = "The name of core infrastructure stack that you created using core-infra module"
  type        = string
}

variable "vpc_tag_key" {
  description = "The tag key of the VPC and subnets"
  type        = string
  default     = "Name"
}

variable "vpc_tag_value" {
  # if left blank then {core_stack_name} will be used
  description = "The tag value of the VPC and subnets"
  type        = string
  default     = ""
}

variable "public_subnets_tag_value" {
  # if left blank then {core_stack_name}-public- will be used
  description = "The value tag of the public subnets"
  type        = string
  default     = ""
}

variable "private_subnets_tag_value" {
  # if left blank then {core_stack_name}-private- will be used
  description = "The value tag of the private subnets"
  type        = string
  default     = ""
}

variable "ecs_cluster_name" {
  # if left blank then {core_stack_name} will be used
  description = "The ID of the ECS cluster"
  type        = string
  default     = ""
}

variable "ecs_task_execution_role_name" {
  # if left blank then {core_stack_name}-execution will be used
  description = "The ARN of the task execution role"
  type        = string
  default     = ""
}

# Application variables
variable "buildspec_path" {
  description = "The location of the buildspec file"
  type        = string
  default     = "./application-code/nodejs-demoapp/templates/buildspec.yml"
}

variable "manifest_buildspec_path" {
  description = "The location of the multi architecture manifest buildspec file"
  type        = string
  default     = "./application-code/nodejs-demoapp/templates/buildspec_manifest.yml"
}

variable "folder_path" {
  description = "The location of the application code and Dockerfile files"
  type        = string
  default     = "./application-code/nodejs-demoapp/."
}

variable "repository_owner" {
  description = "The name of the owner of the Github repository"
  type        = string
}

variable "repository_name" {
  description = "The name of the Github repository"
  type        = string
  default     = "terraform-aws-ecs-blueprints"
}

variable "repository_branch" {
  description = "The name of branch the Github repository, which is going to trigger a new CodePipeline excecution"
  type        = string
  default     = "main"
}

variable "github_token_secret_name" {
  description = "The name of branch the Github repository, which is going to trigger a new CodePipeline excecution"
  type        = string
}

# application related input parameters
variable "service_name" {
  description = "The service name"
  type        = string
  default     = "ecsdemo-multi-arch"
}

variable "namespace" {
  description = "The service discovery namespace"
  type        = string
  default     = "default"
}

variable "desired_count" {
  description = "The number of task replicas for service"
  type        = number
  default     = 1
}

# listener settings for the load balanced service
variable "listener_port" {
  description = "The listener port"
  type        = number
  default     = 80
}

variable "listener_protocol" {
  description = "The listener protocol"
  type        = string
  default     = "HTTP"
}

# target health check
variable "health_check_path" {
  description = "The health check path"
  type        = string
  default     = "/"
}

# variable "health_check_protocol" {
#   description = "The health check protocol"
#   type        = string
#   default     = "http"
# }

variable "health_check_matcher" {
  description = "The health check passing codes"
  type        = string
  default     = "200-299"
}

variable "task_cpu" {
  description = "The task vCPU size"
  type        = number
}

variable "task_memory" {
  description = "The task memory size"
  type        = string
}

variable "container_name" {
  description = "The container name to use in service task definition"
  type        = string
  default     = "ecsdemo-frontend"
}

variable "container_port" {
  description = "The container port to serve traffic"
  type        = number
  default     = 3000
}

variable "container_protocol" {
  description = "The container traffic protocol"
  type        = string
  default     = "HTTP"
}

# Provide a list of map objects
# Each map object has container definition parameters
# The required parameters are container_name, container_image, port_mappings
# [
#  {
#    "container_name":"monitoring-agent",
#    "container_image": "img-repo-url"},
#    "port_mappings" : [{ containerPort = 9090, hostPort =9090, protocol = tcp}]
#  }
# ]
# see modules/ecs-container-definition for full set of parameters
# map_environment and map_secrets are common to add in container definition
variable "sidecar_container_definitions" {
  description = "List of container definitions to add to the task"
  type        = list(any)
  default     = []
}
