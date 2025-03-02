module "state_management" {
  source = "./state-management"
}

module "container_registry" {
  source = "./container-registry"
}

module "core_infra" {
  source = "./core-infra"
}

module "lb_service" {
  source                         = "./lb-service"
  ecr_repository_url             = module.container_registry.ecr_repository_url
  cluster_arn                    = module.core_infra.cluster_arn
  service_discovery_namespace_id = module.core_infra.service_discovery_namespace_id
  vpc_id                         = module.core_infra.vpc_id
  public_subnets                 = module.core_infra.public_subnets
  private_subnets                = module.core_infra.private_subnets
  private_subnet_objects         = module.core_infra.private_subnet_objects
}
