from distutils import util

from aws_cdk import App, Environment
from components.core_infrastructure_construct import CoreInfrastructureProps
from core_infra.lib.core_infra_stack import CoreInfraStack
from dotenv import dotenv_values
from lib.gen_ai_rag_stack import GenAIRagServiceStack
from lib.gen_ai_rag_stack_props import GenAIRagServiceStackProps

from other_stack.bedrock_agent_stack import BedrockAgentStack

app = App()

env_config = dotenv_values(".env")

deploy_core = bool(util.strtobool(env_config["deploy_core_stack"]))
deploy_bedrock = bool(util.strtobool(env_config.pop("deploy_bedrock_agent")))

if deploy_bedrock:
    BedrockAgentStack(
        app,
        "BedrockAgentStack",
        env=Environment(
            account=env_config["account_number"],
            region=env_config["aws_region"],
        ),
    )

gen_ai_rag_stack_props = GenAIRagServiceStackProps(**env_config)

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
    gen_ai_rag_stack_props.vpc = core_stack.vpc
    gen_ai_rag_stack_props.ecs_cluster_name = core_stack.ecs_cluster_name
    namespaces = [
        ns
        for ns in core_stack.private_dns_namespaces
        if ns.namespace_name == gen_ai_rag_stack_props.namespace_name
    ][0]

    gen_ai_rag_stack_props.ecs_task_execution_role_arn = core_stack.ecs_task_execution_role_arn


gen_ai_rag_service_stack = GenAIRagServiceStack(
    app,
    "GenAIRAGService",
    gen_ai_rag_stack_props,
    env=Environment(
        account=gen_ai_rag_stack_props.account_number,
        region=gen_ai_rag_stack_props.aws_region,
    ),
)

gen_ai_rag_service_stack.validate_stack_props()

app.synth()
