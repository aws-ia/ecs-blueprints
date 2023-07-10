from distutils import util

from aws_cdk import App, Environment
from components.core_infrastructure_construct import CoreInfrastructureProps
from core_infra.lib.core_infra_stack import CoreInfraStack
from dotenv import dotenv_values
from lib.event_asso_service_stack import EventAssociatedServiceStack
from lib.event_asso_service_stack_props import EventAssociatedServiceStackProps

app = App()

env_config = dotenv_values(".env")

deploy_core = bool(util.strtobool(env_config["deploy_core_stack"]))

event_asso_stack_props = EventAssociatedServiceStackProps(**env_config)

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
    event_asso_stack_props.vpc = core_stack.vpc
    event_asso_stack_props.ecs_cluster_name = core_stack.ecs_cluster_name
    event_asso_stack_props.sd_namespace = [
        ns
        for ns in core_stack.private_dns_namespaces
        if ns.namespace_name == event_asso_stack_props.namespace_name
    ][0]

    event_asso_stack_props.ecs_task_execution_role_arn = core_stack.ecs_task_execution_role_arn

event_asso_service_stack = EventAssociatedServiceStack(
    app,
    "EventBridgeAssociatedService",
    event_asso_stack_props,
    env=Environment(
        account=event_asso_stack_props.account_number,
        region=event_asso_stack_props.aws_region,
    ),
)

event_asso_service_stack.validate_stack_props()

app.synth()
