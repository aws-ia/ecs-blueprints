from aws_cdk import PhysicalName, Stack
from aws_cdk.aws_ec2 import Vpc
from aws_cdk.aws_ecs import Cluster, ContainerImage, LogDriver
from aws_cdk.aws_ecr_assets import Platform
from aws_cdk.aws_ecs_patterns import (
    ApplicationLoadBalancedFargateService,
    ApplicationLoadBalancedTaskImageOptions,
)
from aws_cdk.aws_iam import (
    Role,
    PolicyStatement,
    Effect,
    ServicePrincipal
)
from aws_cdk.aws_logs import LogGroup, RetentionDays
from aws_cdk.aws_servicediscovery import PrivateDnsNamespace
from generative_ai_service.lib.gen_ai_service_stack_props import GenAIServiceStackProps

class GenAIServiceStack(Stack):
    def __init__(
        self,
        scope: Stack,
        id: str,
        gen_ai_service_stack_prop: GenAIServiceStackProps,
        **kwargs
    ):

        super().__init__(scope, id, **kwargs)

        self.stack_props = gen_ai_service_stack_prop
        self._ecs_cluster = None
        self._ecs_task_execution_role = None
        self._vpc = self.stack_props.vpc if self.stack_props.vpc else None
        self._sd_namespace = (
            self.stack_props.sd_namespace if self.stack_props.sd_namespace else None
        )

        # Amazon CloudWatch log group
        log_group = LogGroup(
            self,
            "GenAIServiceLogGroup",
            retention=RetentionDays.ONE_WEEK,
            log_group_name=PhysicalName.GENERATE_IF_NEEDED,
        )

        # ECS Task Role
        self.task_role = Role(
            self,
            'GenAIServiceTaskRole',
            role_name='GenAIServiceTaskRole',
            assumed_by=ServicePrincipal('ecs-tasks.amazonaws.com'),
            description='ECS Task role for Gen AI service'
        )

        # AWS Fargate task container defintion
        fargate_task_image = ApplicationLoadBalancedTaskImageOptions(
            container_name=self.stack_props.container_name,
            # build container image from local folder
            # image=ContainerImage.from_asset("web-app", platform=Platform.LINUX_AMD64),
            # load pre-built image from public repository
            image=ContainerImage.from_registry(
                self.stack_props.container_image
            ),
            environment={'region': self.stack_props.aws_region},
            container_port=self.stack_props.container_port,
            execution_role=self.ecs_task_execution_role,
            log_driver=LogDriver.aws_logs(
                stream_prefix="ecs",
                log_group=log_group,
            ),
            task_role=self.task_role
        )

        # ECS service with Application Load Balancer
        self.fargate_service = ApplicationLoadBalancedFargateService(
            self,
            "GenAIFargateLBService",
            service_name=self.stack_props.service_name,
            cluster=self.ecs_cluster,
            cpu=int(self.stack_props.task_cpu),
            memory_limit_mib=int(self.stack_props.task_memory),
            desired_count=self.stack_props.desired_count,
            enable_execute_command=True,
            public_load_balancer=True,
            task_image_options=fargate_task_image,
            enable_ecs_managed_tags=True
        )

        # Add ECS Task IAM Role
        self.task_role.add_to_policy(
            PolicyStatement(
                effect=Effect.ALLOW,
                actions = ["ssm:GetParameter"],
                resources = ["arn:aws:ssm:*"]
            )
        )

        self.task_role.add_to_policy(
            PolicyStatement(
                effect=Effect.ALLOW,
                actions=["sagemaker:InvokeEndpoint", "aoss:*"],
                resources=["*"]
            )
        )

        # ECS Service Auto Scaling policy
        scalable_target = self.fargate_service.service.auto_scale_task_count(
            min_capacity=1, max_capacity=5
        )

        scalable_target.scale_on_cpu_utilization(
            "CpuScaling", target_utilization_percent=50
        )

    @property
    def vpc(self):
        if not self._vpc:
            self._vpc = Vpc.from_lookup(
                self, "VpcLookup", vpc_name=self.stack_props.vpc_name
            )

        return self._vpc

    @property
    def sd_namespace(self):
        if not self._sd_namespace:
            self._sd_namespace = (
                PrivateDnsNamespace.from_private_dns_namespace_attributes(
                    self,
                    "SDNamespaceLookup",
                    namespace_name=self.stack_props.namespace_name,
                    namespace_arn=self.stack_props.namespace_arn,
                    namespace_id=self.stack_props.namespace_id,
                )
            )

        return self._sd_namespace

    @property
    def ecs_cluster(self):
        if not self._ecs_cluster:
            self._ecs_cluster = Cluster.from_cluster_attributes(
                self,
                "EcsClusterLookup",
                cluster_name=self.stack_props.ecs_cluster_name,
                security_groups=[],
                vpc=self.vpc,
                default_cloud_map_namespace=self.sd_namespace,
            )

        return self._ecs_cluster

    @property
    def ecs_task_execution_role(self) -> Role:
        if not self._ecs_task_execution_role:
            self._ecs_task_execution_role = Role.from_role_arn(
                self,
                "EcsTaskRoleFromArn",
                self.stack_props.ecs_task_execution_role_arn,
            )

        return self._ecs_task_execution_role

    def validate_stack_props(self):
        if (
            self.stack_props.account_number == "<ACCOUNT_NUMBER>"
            or self.stack_props.aws_region == "<REGION>"
        ):
            raise ValueError(
                "Environment values needs to be set for account_number, aws_region"
            )
