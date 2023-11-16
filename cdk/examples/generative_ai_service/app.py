from distutils import util

from aws_cdk import App, Environment
from components.core_infrastructure_construct import CoreInfrastructureProps
from core_infra.lib.core_infra_stack import CoreInfraStack
from dotenv import dotenv_values
from lib.gen_ai_service_stack import GenAIServiceStack
from lib.gen_ai_service_stack_props import GenAIServiceStackProps

from sagemaker_uri_script import *
from other_stack.txt2img_generative_ai_stack import GenerativeAITxt2ImgSagemakerStack
from other_stack.txt2txt_generative_ai_stack import GenerativeAITxt2TxtSagemakerStack
from other_stack.opensearch_vector_stack import OpenSearchVectorEngineStack

app = App()

env_config = dotenv_values(".env")

deploy_core = bool(util.strtobool(env_config["deploy_core_stack"]))
deploy_jumpstart = bool(util.strtobool(env_config.pop("deploy_jumpstart_stack")))

# opensearch stack
if 'deploy_opensearch' not in env_config:
    deploy_opensearch = False
else:
    deploy_opensearch = bool(util.strtobool(env_config.pop("deploy_opensearch")))

if deploy_jumpstart:
    if "txt2img_model_id" in env_config:
        model_info=get_sagemaker_uris(
            model_id=env_config.pop("txt2img_model_id"),
            instance_type=env_config.pop("txt2img_inference_instance_type"),
            region_name=env_config["aws_region"]
        )

        # Txt2Img generative AI sagemaker stack
        GenerativeAITxt2ImgSagemakerStack(
            app,
            "GenAITxt2ImgSageMakerStack",
            model_info=model_info,
            env=Environment(
                account=env_config["account_number"],
                region=env_config["aws_region"],
            ),
        )
    if "txt2txt_model_id" in env_config:
        model_info=get_sagemaker_uris(
            model_id=env_config.pop("txt2txt_model_id"),
            instance_type=env_config.pop("txt2txt_inference_instance_type"),
            region_name=env_config["aws_region"]
        )

        # Txt2Txt generative AI sagemaker stack
        GenerativeAITxt2TxtSagemakerStack(
            app,
            "GenAITxt2TxtSageMakerStack",
            model_info=model_info,
            env=Environment(
                account=env_config["account_number"],
                region=env_config["aws_region"],
            ),
        )

if deploy_opensearch:
    OpenSearchVectorEngineStack(
        app,
        "OpenSearchVectorEngineStack",
        env=Environment(
            account=env_config["account_number"],
            region=env_config["aws_region"],
        ),
    )

gen_ai_stack_props = GenAIServiceStackProps(**env_config)

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
    gen_ai_stack_props.vpc = core_stack.vpc
    gen_ai_stack_props.ecs_cluster_name = core_stack.ecs_cluster_name
    namespaces = [ns for ns in core_stack.private_dns_namespaces if ns.namespace_name == gen_ai_stack_props.namespace_name]
    if namespaces:
        gen_ai_stack_props.sd_namespace = namespaces[0]

    gen_ai_stack_props.ecs_task_execution_role_arn = core_stack.ecs_task_execution_role_arn


gen_ai_service_stack = GenAIServiceStack(
    app,
    "GenAIService",
    gen_ai_stack_props,
    env=Environment(
        account=gen_ai_stack_props.account_number,
        region=gen_ai_stack_props.aws_region,
    ),
)

gen_ai_service_stack.validate_stack_props()

app.synth()
