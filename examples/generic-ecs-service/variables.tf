variable "region" {
  description = "The aws region for the service"
  type = string 
  default = "us-west-2"
}

variable "ecs_cluster_name" {
  description = "The ECS cluster name in which the resources will be created"
  type        = string
  default     = "core-infra"
}

################################################################################
# Service
################################################################################
variable "service_name" {
  description = "The name for the ecs service"
  type        = string
}

variable "deployment_name" {
  description = "The name of related k8s deployment"
  type        = string
  default     = ""
}

variable "service_type" {
  description = "The type of service"
  type        = string
  default     = "ClusterIP"
}

variable "service_namespace" {
  description = "Service DNS namespace for CloudMap"
  type        = string
  default     = "default"
}

variable "deployment_tags" {
  description = "tags"
  type        = map(string)
  default     = {}
}
variable "task_tags" {
  description = "tags"
  type        = map(string)
  default     = {}
}
variable "label_selector" {
  description = "tags"
  type        = map(string)
  default     = {}
}

variable "desired_count" {
  description = "The desired number of instantiations of the task definition to keep running on the service."
  type        = number
  default     = 1
}

variable "listener_port" {
  description = "Listener port for the load balancer"
  type = number
  default = 80
}

variable "listener_protocol" {
  description = "Listener protocol"
  type = string
  default = "HTTP"
}

variable "deployment_minimum_healthy_percent" {
  description = "The minimum number of tasks, specified as a percentage of the Amazon ECS service's DesiredCount value, that must continue to run and remain healthy during a deployment."
  type        = number
  default     = 100
}

variable "deployment_maximum_percent" {
  description = "Maximum percentage of task able to be deployed"
  type        = number
  default     = 200
}

################################################################################
# Task Definition
################################################################################

variable "lb_container_name" {
  description = "The container name for the LB"
  type        = string
}

variable "lb_container_port" {
  description = "The port that the container will use to listen to requests"
  type        = number
}

variable "lb_health_check_path" {
  description = "Path for LB health check"
  type        = string
  default     = "/"
}

variable "lb_health_check_matcher_codes" {
  description = "HTTP health check passing codes"
  type        = string
  default     = "200-299"
}


variable "cpu" {
  description = "The number of cpu units used by the task."
  type        = number
  default     = 256
}

variable "memory" {
  description = "The number of cpu units used by the task."
  type        = number
  default     = 512
}

################################################################################
# Container Definition
################################################################################

variable "containers" {
  description = "Map of maps that define container definitions to create"
  type        = any
  default     = {}
}

# Containers can have env variable values derived from SSM Parameter store
# To create and store such values provide a list containing
# {"name"="", value=""}
variable "ssm_parameters" {
  description = "To create SSM String Parameters used in container env variables"
  type = list
  default = []
}

# values are expected to be base64encoded 
variable "ssm_secrets" {
  description = "To create SSM SecureString Parameters used in container env variables"
  type = list
  default = []
}

