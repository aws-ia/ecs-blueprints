from distutils import util
from os import getenv

from aws_cdk import App, Environment, Stack
from core_infra.core_infra_stack import CoreInfraStack
from dotenv import dotenv_values
from lb_service_stack import LoadBalancedServiceStack, LoadBalancedServiceStackProps
from lib.core_infrastructure_construct import CoreInfrastructureProps

app = App()

env_config = dotenv_values(".env")

deploy_core = bool(util.strtobool(env_config["deploy_core_stack"]))

lb_stack_props = LoadBalancedServiceStackProps(**env_config)

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
    lb_stack_props.vpc = core_stack.vpc
    lb_stack_props.ecs_cluster_name = core_stack.ecs_cluster_name
    lb_stack_props.sd_namespace = [
        ns
        for ns in core_stack.private_dns_namespaces
        if ns.namespace_name == lb_stack_props.namespace_name
    ][0]
    lb_stack_props.ecs_task_execution_role_arn = core_stack.ecs_task_execution_role_arn

lb_service_stack = LoadBalancedServiceStack(
    app,
    "FrontendService",
    lb_stack_props,
    env=Environment(
        account=lb_stack_props.account_number,
        region=lb_stack_props.aws_region,
    ),
)

app.synth()
