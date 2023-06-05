from distutils import util

from aws_cdk import App, Environment
from components.core_infrastructure_construct import CoreInfrastructureProps
from core_infra.lib.core_infra_stack import CoreInfraStack
from dotenv import dotenv_values
from lib.fis_service_stack import FISServiceStack
from lib.fis_service_stack_props import FISServiceStackProps

app = App()

env_config = dotenv_values(".env")

deploy_core = bool(util.strtobool(env_config["deploy_core_stack"]))

fis_stack_props = FISServiceStackProps(**env_config)

if deploy_core:
    core_config = {
        i
        for i in list(env_config.items())
        if i[0] in CoreInfrastructureProps().__dict__.keys()
    }

    core_props = CoreInfrastructureProps(**dict(core_config))
    core_stack = CoreInfraStack(
        app,
        "CoreInfraStack",
        core_infra_props=core_props,
        env=Environment(
            account=core_props.account_number,
            region=core_props.aws_region,
        ),
    )
    fis_stack_props.vpc = core_stack.vpc
    fis_stack_props.ecs_cluster_name = core_stack.ecs_cluster_name

    fis_stack_props.sd_namespace = [
        ns
        for ns in core_stack.private_dns_namespaces
        if ns.namespace_name == fis_stack_props.namespace_name
    ][0]

    fis_stack_props.ecs_task_execution_role_arn = core_stack.ecs_task_execution_role_arn

fis_service_stack = FISServiceStack(
    app,
    "FISService",
    fis_stack_props,
    env=Environment(
        account=fis_stack_props.account_number,
        region=fis_stack_props.aws_region,
    ),
)

fis_service_stack.validate_stack_props()

app.synth()
