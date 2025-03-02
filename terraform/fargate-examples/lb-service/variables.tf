variable "cluster_arn" {
  type        = string
  description = "The ARN of the core infra cluster"
}
variable "ecr_repository_url" {
  type        = string
  description = "The URL of the ECR repo"
}
variable "service_discovery_namespace_id" {
  type        = string
  description = "The id of the private service discovery namespace"
}
variable "vpc_id" {
  type        = string
  description = "The ID of the VPC created in core infra"
}
variable "public_subnets" {
  type        = list(string)
  description = "A list of public subnets"
}
variable "private_subnets" {
  type        = list(string)
  description = "A list of private subnets"
}
variable "private_subnet_objects" {
  type = list(object({
    availability_zone = string
    cidr_block        = string
  }))
  description = "A list of private subnet objects"
}
