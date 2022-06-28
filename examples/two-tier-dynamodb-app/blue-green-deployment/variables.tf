variable "github_token" {
  description = "Personal access token from Github"
  type        = string
  sensitive   = true
}

variable "buildspec_path" {
  description = "The location of the buildspec file"
  type        = string
  default     = "./templates/buildspec_bluegreen.yml"
}

variable "folder_path_server" {
  description = "The location of the server files"
  type        = string
  default     = "./application-code/server/."
}

variable "folder_path_client" {
  description = "The location of the client files"
  type        = string
  default     = "./application-code/client/."
}

variable "container_name" {
  description = "The name of the container of each ECS service"
  type        = map(string)
  default = {
    server = "Container-server"
    client = "Container-client"
  }
}

variable "iam_role_name" {
  description = "The name of the IAM Role for each service"
  type        = map(string)
  default = {
    devops        = "DevOps-Role"
    ecs           = "ECS-task-excecution-Role"
    ecs_task_role = "ECS-task-Role"
    codedeploy    = "CodeDeploy-Role"
  }
}

variable "repository_owner" {
  description = "The name of the owner of the Github repository"
  type        = string
}

variable "repository_name" {
  description = "The name of the Github repository"
  type        = string
}

variable "repository_branch" {
  description = "The name of branch the Github repository, which is going to trigger a new CodePipeline excecution"
  type        = string
  default     = "main"
}

# ------- ECS -------

variable "ecs_service_name" {
  description = "The name each ECS service"
  type        = map(any)
}

variable "ecs_desired_tasks" {
  description = "The amount of desired ECS tasks"
  type        = map(any)
}

variable "seconds_health_check_grace_period" {
  description = "Number of seconds for the task health check"
  type        = number
}

variable "ecs_task_server_cpu" {
  description = "Amount of CPU to be specified in the task definition"
  type        = number
}

variable "ecs_task_server_memory" {
  description = "Amount of memory to be specified in the task definition"
  type        = string
}

variable "ecs_task_client_cpu" {
  description = "Amount of CPU to be specified in the task definition"
  type        = number
}

variable "ecs_task_client_memory" {
  description = "Amount of memory to be specified in the task definition"
  type        = string
}

variable "ecs_autoscaling_min_capacity" {
  description = "Minimum desired amount of running task"
  type        = map(any)
}

variable "ecs_autoscaling_max_capacity" {
  description = "Maximum desired amount of running task"
  type        = map(any)
}

# ------- Application -------

variable "port_app_server" {
  description = "The port used by your server application"
  type        = number
  default     = 3001
}

variable "port_app_client" {
  description = "The port used by your client application"
  type        = number
  default     = 80
}

variable "memory_threshold" {
  description = "The desired threashold for memory consumption"
  type        = map(any)
}

variable "cpu_threshold" {
  description = "The desired threashold for CPU consumption"
  type        = map(any)
}
