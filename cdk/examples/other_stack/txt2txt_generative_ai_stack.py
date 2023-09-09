from aws_cdk import Stack
from aws_cdk.aws_iam import (
    Role,
    ServicePrincipal,
    ManagedPolicy
)
from aws_cdk.aws_sagemaker import CfnModel, CfnEndpointConfig, CfnEndpoint
from aws_cdk.aws_ssm import StringParameter
from constructs import Construct

class GenerativeAITxt2TxtSagemakerStack(Stack):
    def __init__(
        self,
        scope: Construct,
        id: str,
        model_info,
        **kwargs
    ) -> None:

        super().__init__(scope, id, **kwargs)

        # model name
        model_info["model_name"]="HuggingfaceText2TextFlan"

        # SageMaker Model IAM Role
        self.sagemaker_role = Role(
            self,
            "GenAISageMakerPolicy",
            assumed_by=ServicePrincipal("sagemaker.amazonaws.com"),
            managed_policies=[
                ManagedPolicy.from_aws_managed_policy_name("AmazonS3FullAccess"),
                ManagedPolicy.from_aws_managed_policy_name("AmazonSageMakerFullAccess")
            ]
        )

        # SageMaker model
        self.sagemaker_model = CfnModel(
            self,
            model_info["model_name"]+"Model",
            execution_role_arn=self.sagemaker_role.role_arn,
            model_name = model_info["model_name"]+"-Model",
            containers=[
                CfnModel.ContainerDefinitionProperty(
                    image=model_info["model_docker_image"],
                    model_data_url= "s3://"+model_info["model_bucket_name"]+"/"+model_info["model_bucket_key"],
                    environment={
                        "MODEL_CACHE_ROOT": "/opt/ml/model",
                        "SAGEMAKER_ENV": "1",
                        "SAGEMAKER_MODEL_SERVER_TIMEOUT": "3600",
                        "SAGEMAKER_MODEL_SERVER_WORKERS": "1",
                        "SAGEMAKER_PROGRAM": "inference.py",
                        "SAGEMAKER_REGION": model_info["region_name"],
                        "SAGEMAKER_SUBMIT_DIRECTORY": "/opt/ml/model/code/",
                        "TS_DEFAULT_WORKERS_PER_MODEL": "1"
                    }
                )
            ]
        )

        # SageMaker Endpoint config
        self.sagemaker_config = CfnEndpointConfig(
            self,
            model_info["model_name"]+"Config",
            endpoint_config_name=model_info["model_name"]+"-Config",
            production_variants=[
                CfnEndpointConfig.ProductionVariantProperty(
                    model_name=self.sagemaker_model.attr_model_name,
                    variant_name="AllTraffic",
                    initial_variant_weight=1,
                    initial_instance_count=1,
                    instance_type=model_info["instance_type"]
                )
            ]
        )

        # SageMaker Endpoint
        self.sagemaker_endpoint = CfnEndpoint(
            self,
            model_info["model_name"]+"Endpoint",
            endpoint_name=model_info["model_name"]+"-Endpoint",
            endpoint_config_name=self.sagemaker_config.attr_endpoint_config_name
        )

        # endpoint.node.add_dependency(logs_policy)
        # endpoint.node.add_dependency(ecr_policy)

        # Store SageMaker Endpoint name to Parameter Store
        StringParameter(self, "txt2txt_sm_endpoint", parameter_name="txt2txt_sm_endpoint", string_value=self.sagemaker_endpoint.attr_endpoint_name)
