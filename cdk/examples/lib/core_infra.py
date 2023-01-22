from distutils import util

from aws_cdk import CfnOutput, PhysicalName, RemovalPolicy, StackProps
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


class CoreInfraProps(StackProps):
    def __init__(
        self,
        core_stack_name="a_core_stack",
        aws_region="us-east-1",
        namespaces="ns1,ns2",
        vpc_cidr="10.0.0.0/16",
        enable_nat_gw=False,
        az_count=3,
    ) -> None:
        self.core_stack_name = core_stack_name
        self.aws_region = aws_region
        self.vpc_cidr = vpc_cidr
        self.namespaces = namespaces.split(",")
        self.enable_nat_gw = bool(util.strtobool(enable_nat_gw))
        self.az_count = int(az_count)


class CoreInfrastructureStack(Construct):
    def __init__(
        self, scope: Construct, id: str, core_infra_props: CoreInfraProps, **kwargs
    ) -> None:
        super().__init__(scope, id, **kwargs)

        self.vpc_id = None
        self.public_subnets = None
        self.private_subnets = None
        self.ecs_cluster_name = None
        self.ecs_cluster_id = None
        self.ecs_task_execution_role_name = None
        self.ecs_task_execution_role_arn = None
        self.ecs_cluster_security_groups = None
        self.sd_namespaces = None

        self.vpc = Vpc(
            self,
            "EcsVpc",
            ip_addresses=IpAddresses.cidr(core_infra_props.vpc_cidr),
            max_azs=core_infra_props.az_count,
            nat_gateways=core_infra_props.az_count
            if core_infra_props.enable_nat_gw
            else 0,
        )

        log_group = LogGroup(
            self,
            "CloudWatchLogGroup",
            log_group_name=f"/aws/ecs/{core_infra_props.core_stack_name}",
            retention=RetentionDays.ONE_WEEK,
            removal_policy=RemovalPolicy.DESTROY,
        )

        execute_command_configuration = ExecuteCommandConfiguration(
            logging=ExecuteCommandLogging.OVERRIDE,
            log_configuration=ExecuteCommandLogConfiguration(
                cloud_watch_log_group=log_group
            ),
        )

        self.cluster = Cluster(
            self,
            "EcsCluster",
            cluster_name=core_infra_props.core_stack_name,
            vpc=self.vpc,
            container_insights=True,
            execute_command_configuration=execute_command_configuration,
        )

        namespaces = core_infra_props.namespaces
        service_discovery = {}

        for namespace in namespaces:
            private_dns_namespace = PrivateDnsNamespace(
                self,
                f"{namespace}-namespace",
                vpc=self.vpc,
                name=f"{namespace}.{self.cluster.cluster_name}.local",
            )
            service_discovery[
                f"{namespace}.{core_infra_props.core_stack_name}.local"
            ] = {}
            service_discovery[f"{namespace}.{core_infra_props.core_stack_name}.local"][
                "arn"
            ] = private_dns_namespace.namespace_arn
            service_discovery[f"{namespace}.{core_infra_props.core_stack_name}.local"][
                "name"
            ] = private_dns_namespace.namespace_name
            service_discovery[f"{namespace}.{core_infra_props.core_stack_name}.local"][
                "id"
            ] = private_dns_namespace.namespace_id

        self.task_execution_role = Role(
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

        cluster_outputs = {"SECGRPS": str(self.cluster.connections.security_groups)}

        if self.cluster.connections.security_groups:
            cluster_outputs["SECGRPS"] = str(
                [x.security_group_id for x in self.cluster.connections.security_groups][
                    0
                ]
            )

        # All Outputs required for other stacks to build
        self.vpc_id = self.vpc.vpc_id
        self.public_subnets = [i.subnet_id for i in self.vpc.public_subnets]
        self.private_subnets = [i.subnet_id for i in self.vpc.private_subnets]
        self.ecs_cluster_name = self.cluster.cluster_name
        self.ecs_cluster_id = self.cluster.cluster_arn
        self.ecs_task_execution_role_arn = self.task_execution_role.role_arn
        self.ecs_task_execution_role_name = self.task_execution_role.role_name
        self.sd_namespaces = service_discovery
        self.ecs_cluster_security_groups = cluster_outputs["SECGRPS"]

        CfnOutput(self, "vpc_id", value=self.vpc.vpc_id)
        CfnOutput(
            self,
            "public_subnets",
            value=str([i.subnet_id for i in self.vpc.public_subnets]),
        )
        CfnOutput(
            self,
            "private_subnets",
            value=str([i.subnet_id for i in self.vpc.private_subnets]),
        )

        CfnOutput(self, "ecs_cluster_name", value=self.cluster.cluster_name)
        CfnOutput(self, "ecs_cluster_id", value=self.cluster.cluster_arn)
        CfnOutput(
            self,
            "ecs_task_execution_role_name",
            value=self.task_execution_role.role_name,
        )
        CfnOutput(
            self,
            "ecs_task_execution_role_arn",
            value=self.task_execution_role.role_arn,
        )
        CfnOutput(self, "sd_namespaces", value=str(service_discovery))

        CfnOutput(
            self,
            "ecs_cluster_security_groups",
            value=cluster_outputs["SECGRPS"],
        )
