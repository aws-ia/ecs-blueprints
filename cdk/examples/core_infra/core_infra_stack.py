from aws_cdk import CfnOutput, RemovalPolicy, Stack, StackProps
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
        core_stack_name,
        aws_region,
        namespaces,
        vpc_cidr="10.0.0.0/16",
        enable_nat_gw=False,
        az_count=3,
    ) -> None:
        self.core_stack_name = core_stack_name
        self.aws_region = aws_region
        self.vpc_cidr = vpc_cidr
        self.namespaces = namespaces
        self.enable_nat_gw = enable_nat_gw
        self.az_count = az_count


class CoreInfrastructureStack(Stack):
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

        vpc = Vpc(
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

        cluster = Cluster(
            self,
            "EcsCluster",
            cluster_name=core_infra_props.core_stack_name,
            vpc=vpc,
            container_insights=True,
            execute_command_configuration=execute_command_configuration,
        )

        namespaces = core_infra_props.namespaces
        service_discovery = {}

        for namespace in namespaces:
            private_dns_namespace = PrivateDnsNamespace(
                self,
                f"{namespace}-namespace",
                vpc=vpc,
                name=f"{namespace}.{cluster.cluster_name}.local",
            )
            service_discovery[
                f"{namespace}.{self.node.try_get_context('core_stack_name')}.local"
            ] = {}
            service_discovery[
                f"{namespace}.{self.node.try_get_context('core_stack_name')}.local"
            ]["arn"] = private_dns_namespace.namespace_arn
            service_discovery[
                f"{namespace}.{self.node.try_get_context('core_stack_name')}.local"
            ]["name"] = private_dns_namespace.namespace_name
            service_discovery[
                f"{namespace}.{self.node.try_get_context('core_stack_name')}.local"
            ]["id"] = private_dns_namespace.namespace_id

        task_execution_role = Role(
            self,
            "FargateContainerRole",
            assumed_by=ServicePrincipal("ecs-tasks.amazonaws.com"),
            managed_policies=[
                ManagedPolicy.from_aws_managed_policy_name(
                    "service-role/AmazonECSTaskExecutionRolePolicy"
                )
            ],
        )

        cluster_outputs = {"SECGRPS": str(cluster.connections.security_groups)}

        if cluster.connections.security_groups:
            cluster_outputs["SECGRPS"] = str(
                [x.security_group_id for x in cluster.connections.security_groups][0]
            )

        # All Outputs required for other stacks to build
        CfnOutput(self, "vpc_id", value=vpc.vpc_id)
        self.vpc_id = vpc.vpc_id
        self.public_subnets = [i.subnet_id for i in vpc.public_subnets]
        self.private_subnets = [i.subnet_id for i in vpc.private_subnets]
        self.ecs_cluster_name = cluster.cluster_name
        self.ecs_cluster_id = cluster.cluster_arn
        self.ecs_task_execution_role_arn = task_execution_role.role_arn
        self.ecs_task_execution_role_name = task_execution_role.role_name
        self.sd_namespaces = str(service_discovery)
        self.ecs_cluster_security_groups = cluster_outputs["SECGRPS"]

        CfnOutput(
            self,
            "public_subnets",
            value=str([i.subnet_id for i in vpc.public_subnets]),
        )
        CfnOutput(
            self,
            "private_subnets",
            value=str([i.subnet_id for i in vpc.private_subnets]),
        )

        CfnOutput(self, "ecs_cluster_name", value=cluster.cluster_name)
        CfnOutput(self, "ecs_cluster_id", value=cluster.cluster_arn)
        CfnOutput(
            self,
            "ecs_task_execution_role_name",
            value=task_execution_role.role_name,
        )
        CfnOutput(
            self,
            "ecs_task_execution_role_arn",
            value=task_execution_role.role_arn,
        )
        CfnOutput(self, "sd_namespaces", value=str(service_discovery))

        CfnOutput(
            self,
            "ecs_cluster_security_groups",
            value=cluster_outputs["SECGRPS"],
        )
