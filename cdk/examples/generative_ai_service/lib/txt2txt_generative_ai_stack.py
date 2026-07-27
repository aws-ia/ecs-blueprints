from aws_cdk import Stack
from aws_cdk.aws_iam import (
    PolicyStatement,
    Role,
    ServicePrincipal
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

        model_bucket_arn = (
            f"arn:{self.partition}:s3:::{model_info['model_bucket_name']}"
        )
        model_key_prefix = model_info["model_bucket_key"].lstrip("/")
        image_registry, image_path = model_info["model_docker_image"].split("/", 1)
        image_account = image_registry.split(".", 1)[0]
        image_repository = image_path.split("@", 1)[0].rsplit(":", 1)[0]
        image_repository_arn = (
            f"arn:{self.partition}:ecr:{model_info['region_name']}:"
            f"{image_account}:repository/{image_repository}"
        )

        # SageMaker Model IAM Role
        self.sagemaker_role = Role(
            self,
            "GenAISageMakerPolicy",
            assumed_by=ServicePrincipal("sagemaker.amazonaws.com"),
        )
        self.sagemaker_role.add_to_policy(
            PolicyStatement(
                actions=["s3:GetObject"],
                resources=[f"{model_bucket_arn}/{model_key_prefix}*"],
            )
        )
        self.sagemaker_role.add_to_policy(
            PolicyStatement(
                actions=["s3:GetBucketLocation"],
                resources=[model_bucket_arn],
            )
        )
        self.sagemaker_role.add_to_policy(
            PolicyStatement(
                actions=["s3:ListBucket"],
                resources=[model_bucket_arn],
                conditions={
                    "StringLike": {"s3:prefix": [f"{model_key_prefix}*"]}
                },
            )
        )
        self.sagemaker_role.add_to_policy(
            PolicyStatement(
                actions=["ecr:GetAuthorizationToken"],
                resources=["*"],
            )
        )
        self.sagemaker_role.add_to_policy(
            PolicyStatement(
                actions=[
                    "ecr:BatchCheckLayerAvailability",
                    "ecr:BatchGetImage",
                    "ecr:GetDownloadUrlForLayer",
                ],
                resources=[image_repository_arn],
            )
        )
        self.sagemaker_role.add_to_policy(
            PolicyStatement(
                actions=[
                    "logs:CreateLogGroup",
                    "logs:CreateLogStream",
                    "logs:DescribeLogStreams",
                    "logs:PutLogEvents",
                ],
                resources=[
                    f"arn:{self.partition}:logs:{self.region}:{self.account}:"
                    "log-group:/aws/sagemaker/Endpoints/*"
                ],
            )
        )
        # PutMetricData supports only condition-based scoping, not resource ARNs.
        self.sagemaker_role.add_to_policy(
            PolicyStatement(
                actions=["cloudwatch:PutMetricData"],
                resources=["*"],
                conditions={
                    "StringEquals": {"cloudwatch:namespace": "/aws/sagemaker/Endpoints"}
                },
            )
        )

        # SageMaker model
        self.sagemaker_model = CfnModel(
            self,
            model_info["model_name"]+"Model",
            enable_network_isolation=True,
            execution_role_arn=self.sagemaker_role.role_arn,
            model_name = model_info["model_name"]+"-Model",
            containers=[
                CfnModel.ContainerDefinitionProperty(
                    image=model_info["model_docker_image"],
                    model_data_source=CfnModel.ModelDataSourceProperty(
                        s3_data_source=CfnModel.S3DataSourceProperty(
                            compression_type='None',
                            s3_data_type='S3Prefix',
                            s3_uri=f's3://{model_info["model_bucket_name"]}/{model_info["model_bucket_key"]}',
                            model_access_config=CfnModel.ModelAccessConfigProperty(
                                accept_eula=True,
                            ),
                        ),
                    ),
                    environment={
                        "MODEL_CACHE_ROOT": "/opt/ml/model",
                        "SAGEMAKER_ENV": "1",
                        "ENDPOINT_SERVER_TIMEOUT": "3600",
                        "SAGEMAKER_MODEL_SERVER_WORKERS": "1",
                        "SAGEMAKER_PROGRAM": "inference.py",
                        "SAGEMAKER_REGION": model_info["region_name"],
                        "HF_MODEL_ID": "/opt/ml/model",
                        "MAX_INPUT_LENGTH": "1024",
                        "MAX_TOTAL_TOKENS": "2048",
                        "SM_NUM_GPUS": "1",
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
