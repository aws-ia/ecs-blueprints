from components.config import find_namespace, parse_bool

from aws_cdk import App, Environment
from components.core_infrastructure_construct import CoreInfrastructureProps
from core_infra.lib.core_infra_stack import CoreInfraStack
from dotenv import dotenv_values
from lib.gen_ai_service_stack import GenAIServiceStack
from lib.gen_ai_service_stack_props import GenAIServiceStackProps

from lib.opensearch_vector_stack import OpenSearchVectorEngineStack

app = App()

env_config = dict(dotenv_values(".env"))
sagemaker_endpoint_names = []

deploy_core = parse_bool(env_config["deploy_core_stack"])
deploy_jumpstart = parse_bool(env_config.pop("deploy_jumpstart_stack", "false"))
txt2img_model_id = env_config.pop("txt2img_model_id", None)
txt2img_instance_type = env_config.pop("txt2img_inference_instance_type", None)
txt2txt_model_id = env_config.pop("txt2txt_model_id", None)
txt2txt_instance_type = env_config.pop("txt2txt_inference_instance_type", None)

# opensearch stack
deploy_opensearch = parse_bool(env_config.pop("deploy_opensearch", "false"))

if deploy_jumpstart:
    from lib.txt2img_generative_ai_stack import (
        GenerativeAITxt2ImgSagemakerStack,
    )
    from lib.txt2txt_generative_ai_stack import (
        GenerativeAITxt2TxtSagemakerStack,
    )
    from sagemaker_uri_script import get_sagemaker_uris

    if txt2img_model_id:
        if not txt2img_instance_type:
            raise ValueError(
                "txt2img_inference_instance_type is required with txt2img_model_id"
            )
        model_info=get_sagemaker_uris(
            model_id=txt2img_model_id,
            instance_type=txt2img_instance_type,
            region_name=env_config["aws_region"]
        )

        # Txt2Img generative AI sagemaker stack
        txt2img_stack = GenerativeAITxt2ImgSagemakerStack(
            app,
            "GenAITxt2ImgSageMakerStack",
            model_info=model_info,
            env=Environment(
                account=env_config["account_number"],
                region=env_config["aws_region"],
            ),
        )
        sagemaker_endpoint_names.append(
            txt2img_stack.sagemaker_endpoint.attr_endpoint_name
        )
    if txt2txt_model_id:
        if not txt2txt_instance_type:
            raise ValueError(
                "txt2txt_inference_instance_type is required with txt2txt_model_id"
            )
        model_info=get_sagemaker_uris(
            model_id=txt2txt_model_id,
            instance_type=txt2txt_instance_type,
            region_name=env_config["aws_region"]
        )

        # Txt2Txt generative AI sagemaker stack
        txt2txt_stack = GenerativeAITxt2TxtSagemakerStack(
            app,
            "GenAITxt2TxtSageMakerStack",
            model_info=model_info,
            env=Environment(
                account=env_config["account_number"],
                region=env_config["aws_region"],
            ),
        )
        sagemaker_endpoint_names.append(
            txt2txt_stack.sagemaker_endpoint.attr_endpoint_name
        )

gen_ai_stack_props = GenAIServiceStackProps(**env_config)
if sagemaker_endpoint_names:
    gen_ai_stack_props.sagemaker_endpoint_names = sagemaker_endpoint_names

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
    gen_ai_stack_props.sd_namespace = find_namespace(
        core_stack.private_dns_namespaces,
        gen_ai_stack_props.namespace_name,
    )

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

if deploy_opensearch:
    opensearch_stack = OpenSearchVectorEngineStack(
        app,
        "OpenSearchVectorEngineStack",
        vpc=gen_ai_service_stack.vpc,
        env=Environment(
            account=env_config["account_number"],
            region=env_config["aws_region"],
        ),
    )
    gen_ai_service_stack.grant_aoss_access(
        opensearch_stack.cfn_collection.attr_arn,
        opensearch_stack.collection_name,
    )

app.synth()
