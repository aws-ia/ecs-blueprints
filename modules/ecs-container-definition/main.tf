locals {
  is_not_windows = var.platform != "windows"

  definition = {
    command                = length(var.command) > 0 ? var.command : null
    cpu                    = var.cpu
    dependsOn              = length(var.dependencies) > 0 ? var.dependencies : null # depends_on is a reserved word
    disableNetworking      = local.is_not_windows ? var.disable_networking : null
    dnsSearchDomains       = local.is_not_windows && length(var.dns_search_domains) > 0 ? var.dns_search_domains : null
    dnsServers             = local.is_not_windows && length(var.dns_servers) > 0 ? var.dns_servers : null
    dockerLabels           = length(var.docker_labels) > 0 ? var.docker_labels : null
    dockerSecurityOptions  = length(var.docker_security_options) > 0 ? var.docker_security_options : null
    entrypoint             = length(var.entrypoint) > 0 ? var.entrypoint : null
    environment            = length(var.environment) > 0 ? var.environment : null
    environmentFiles       = length(var.environment_files) > 0 ? var.environment_files : null
    essential              = var.essential
    extraHosts             = local.is_not_windows && length(var.extra_hosts) > 0 ? var.extra_hosts : null
    firelensConfiguration  = length(var.firelens_configuration) > 0 ? var.firelens_configuration : null
    healthCheck            = length(var.health_check) > 0 ? var.health_check : null
    hostname               = var.hostname
    image                  = var.image
    interactive            = var.interactive
    links                  = local.is_not_windows && length(var.links) > 0 ? var.links : null
    linuxParameters        = local.is_not_windows && length(var.linux_parameters) > 0 ? var.linux_parameters : null
    logConfiguration       = length(var.log_configuration) > 0 ? var.log_configuration : null
    memory                 = var.memory
    memoryReservation      = var.memory_reservation
    mountPoints            = length(var.mount_points) > 0 ? var.mount_points : null
    name                   = var.name
    portMappings           = length(var.port_mappings) > 0 ? var.port_mappings : null
    privileged             = local.is_not_windows ? var.privileged : null
    pseudoTerminal         = var.pseudo_terminal
    readonlyRootFilesystem = local.is_not_windows ? var.readonly_root_filesystem : null
    repositoryCredentials  = length(var.repository_credentials) > 0 ? var.repository_credentials : null
    resourceRequirements   = length(var.resource_requirements) > 0 ? var.resource_requirements : null
    secrets                = length(var.secrets) > 0 ? var.secrets : null
    startTimeout           = var.start_timeout
    stopTimeout            = var.stop_timeout
    systemControls         = length(var.system_controls) > 0 ? var.system_controls : null
    ulimits                = local.is_not_windows && length(var.ulimits) > 0 ? var.ulimits : null
    user                   = local.is_not_windows ? var.user : null
    volumesFrom            = length(var.volumes_from) > 0 ? var.volumes_from : null
    workingDirectory       = var.working_directory
  }

  # Strip out all null values, ECS API will provide defaults in place of null/empty values
  container_definition = { for k, v in local.definition : k => v if v != null }
}
