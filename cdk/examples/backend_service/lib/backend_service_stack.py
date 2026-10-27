from aws_cdk import CfnOutput, PhysicalName, RemovalPolicy, Stack
from aws_cdk.aws_ec2 import IpAddresses, Peer, Port, Vpc
from aws_cdk.aws_ecs import (
    CloudMapOptions,
    Cluster,
    ContainerInsights,
    ContainerImage,
    DeploymentCircuitBreaker,
    FargateService,
    FargateTaskDefinition,
    LogDriver,
    PortMapping,
)
from aws_cdk.aws_iam import PolicyStatement
from aws_cdk.aws_logs import LogGroup, RetentionDays
from aws_cdk.aws_servicediscovery import PrivateDnsNamespace
from constructs import Construct

from backend_service.lib.backend_service_stack_props import (
    BackendServiceStackProps,
)


class BackendServiceStack(Stack):
    def __init__(
        self,
        scope: Construct,
        construct_id: str,
        stack_props: BackendServiceStackProps,
        **kwargs,
    ):
        super().__init__(scope, construct_id, **kwargs)
        self.stack_props = stack_props

        self.vpc = Vpc(
            self,
            "Vpc",
            ip_addresses=IpAddresses.cidr(stack_props.vpc_cidr),
            max_azs=stack_props.az_count,
            nat_gateways=1 if stack_props.enable_nat_gw else 0,
            vpc_name=f"{stack_props.ecs_cluster_name}-vpc",
        )

        self.cluster = Cluster(
            self,
            "Cluster",
            cluster_name=stack_props.ecs_cluster_name,
            container_insights_v2=ContainerInsights.ENHANCED,
            vpc=self.vpc,
        )

        self.namespace = PrivateDnsNamespace(
            self,
            "Namespace",
            name=stack_props.namespace_name,
            vpc=self.vpc,
        )

        log_group = LogGroup(
            self,
            "BackendLogGroup",
            retention=RetentionDays.ONE_WEEK,
            log_group_name=PhysicalName.GENERATE_IF_NEEDED,
        )
        log_group.apply_removal_policy(RemovalPolicy.DESTROY)

        task_definition = FargateTaskDefinition(
            self,
            "BackendTaskDefinition",
            cpu=stack_props.task_cpu,
            memory_limit_mib=stack_props.task_memory,
        )
        task_definition.add_to_task_role_policy(
            PolicyStatement(actions=["ec2:DescribeSubnets"], resources=["*"])
        )

        container = task_definition.add_container(
            "BackendContainer",
            image=ContainerImage.from_registry(stack_props.container_image),
            container_name=stack_props.container_name,
            logging=LogDriver.aws_logs(
                stream_prefix="backend",
                log_group=log_group,
            ),
        )
        container.add_port_mappings(
            PortMapping(container_port=stack_props.container_port)
        )

        self.service = FargateService(
            self,
            "BackendFargateService",
            service_name=stack_props.service_name,
            task_definition=task_definition,
            enable_execute_command=True,
            cluster=self.cluster,
            desired_count=stack_props.desired_count,
            circuit_breaker=DeploymentCircuitBreaker(rollback=True),
            min_healthy_percent=100,
            cloud_map_options=CloudMapOptions(
                cloud_map_namespace=self.namespace,
                name="backend",
            ),
            enable_ecs_managed_tags=True,
        )

        self.service.connections.allow_from(
            Peer.ipv4(self.vpc.vpc_cidr_block),
            Port.tcp(stack_props.container_port),
            "Backend clients within this VPC",
        )

        scaling = self.service.auto_scale_task_count(
            min_capacity=stack_props.desired_count,
            max_capacity=10,
        )
        scaling.scale_on_cpu_utilization(
            "BackendCpuScaling",
            target_utilization_percent=50,
        )

        CfnOutput(
            self,
            "BackendEndpoint",
            value=(
                f"http://backend.{stack_props.namespace_name}:"
                f"{stack_props.container_port}"
            ),
        )

    def validate_stack_props(self):
        if (
            self.stack_props.account_number in ["<ACCOUNT_NUMBER>", None]
            or self.stack_props.aws_region in ["<REGION>", None]
        ):
            raise ValueError(
                "Environment values need to be set for account_number and "
                "aws_region"
            )
