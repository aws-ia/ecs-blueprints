from distutils import util

from aws_cdk import PhysicalName, RemovalPolicy, StackProps
from aws_cdk.aws_ec2 import IpAddresses, Vpc
from aws_cdk.aws_ecs import (
    Cluster,
    ExecuteCommandConfiguration,
    ExecuteCommandLogConfiguration,
    ExecuteCommandLogging,
)
from aws_cdk.aws_iam import ManagedPolicy, Role, ServicePrincipal
from aws_cdk.aws_logs import LogGroup, RetentionDays
from aws_cdk.aws_servicediscovery import PrivateDnsNamespace
from constructs import Construct


class CoreInfrastructureProps(StackProps):
    def __init__(
        self,
        ecs_cluster_name="a_core_stack",
        aws_region="us-east-1",
        account_number=None,
        namespaces="ns1",
        vpc_cidr="10.0.0.0/16",
        enable_nat_gw="True",
        az_count="3",
    ) -> None:
        self.account_number = account_number
        self.ecs_cluster_name = ecs_cluster_name
        self.aws_region = aws_region
        self.vpc_cidr = vpc_cidr
        self.namespaces = namespaces.split(",")
        self.enable_nat_gw = bool(util.strtobool(enable_nat_gw))
        self.az_count = int(az_count)


class CoreInfrastructureConstruct(Construct):
    def __init__(
        self,
        scope: Construct,
        id: str,
        core_infra_props: CoreInfrastructureProps,
        **kwargs,
    ) -> None:
        super().__init__(scope, id, **kwargs)

        self.vpc_id = None
        self.public_subnets = None
        self.private_subnets = None
        self.ecs_cluster_name = None
        self.ecs_cluster_id = None
        self.ecs_task_execution_role_name = None
        self.ecs_task_execution_role_arn = None
        # self.ecs_cluster_security_groups = None
        self.private_dns_namespaces = []

        self.vpc = Vpc(
            self,
            "EcsVpc",
            ip_addresses=IpAddresses.cidr(core_infra_props.vpc_cidr),
            max_azs=core_infra_props.az_count,
            nat_gateways=core_infra_props.az_count
            if core_infra_props.enable_nat_gw
            else 0,
            vpc_name=f"{core_infra_props.ecs_cluster_name}-vpc"
        )

        log_group = LogGroup(
            self,
            "CloudWatchLogGroup",
            log_group_name=f"/aws/ecs/{core_infra_props.ecs_cluster_name}",
            retention=RetentionDays.ONE_WEEK,
            removal_policy=RemovalPolicy.DESTROY,
        )

        execute_command_configuration = ExecuteCommandConfiguration(
            logging=ExecuteCommandLogging.OVERRIDE,
            log_configuration=ExecuteCommandLogConfiguration(
                cloud_watch_log_group=log_group
            ),
        )

        self.ecs_cluster = Cluster(
            self,
            "EcsCluster",
            cluster_name=core_infra_props.ecs_cluster_name,
            vpc=self.vpc,
            container_insights=True,
            execute_command_configuration=execute_command_configuration,
        )

        self.private_dns_namespaces = [
            PrivateDnsNamespace(
                self,
                f"{namespace}-namespace",
                vpc=self.vpc,
                name=f"{namespace}.{core_infra_props.ecs_cluster_name}.local",
            )
            for namespace in core_infra_props.namespaces
        ]

        self.ecs_task_execution_role = Role(
            self,
            "FargateContainerRole",
            role_name=PhysicalName.GENERATE_IF_NEEDED,
            assumed_by=ServicePrincipal("ecs-tasks.amazonaws.com"),
            managed_policies=[
                ManagedPolicy.from_aws_managed_policy_name(
                    "service-role/AmazonECSTaskExecutionRolePolicy"
                )
            ],
        )

        # All Outputs required for other stacks to build
        self.vpc_id = self.vpc.vpc_id
        self.public_subnets = [i.subnet_id for i in self.vpc.public_subnets]
        self.private_subnets = [i.subnet_id for i in self.vpc.private_subnets]
        self.ecs_cluster_name = self.ecs_cluster.cluster_name
        self.ecs_cluster_id = self.ecs_cluster.cluster_arn
        self.ecs_task_execution_role_arn = self.ecs_task_execution_role.role_arn
        self.ecs_task_execution_role_name = self.ecs_task_execution_role.role_name
