from aws_cdk import (
    CfnOutput,
    CfnTag,
    Duration,
    RemovalPolicy,
    Stack,
)
from aws_cdk.aws_ec2 import IpAddresses, Peer, Port, SecurityGroup, Vpc
from aws_cdk.aws_ecs import (
    Cluster,
    ContainerDependency,
    ContainerDependencyCondition,
    ContainerInsights,
    ContainerImage,
    CfnExpressGatewayService,
    FargateTaskDefinition,
    FirelensConfig,
    FirelensLogRouterType,
    HealthCheck,
    LogDrivers,
    PortMapping,
)
from aws_cdk.aws_iam import (
    ManagedPolicy,
    Policy,
    PolicyStatement,
    Role,
    ServicePrincipal,
)
from aws_cdk.aws_logs import LogGroup, RetentionDays
from constructs import Construct


class ExpressModeStack(Stack):
    def __init__(
        self,
        scope: Construct,
        construct_id: str,
        enable_custom_task_definition: bool = False,
        **kwargs,
    ):
        super().__init__(scope, construct_id, **kwargs)

        vpc = Vpc(
            self,
            "Vpc",
            ip_addresses=IpAddresses.cidr("10.30.0.0/16"),
            max_azs=2,
            nat_gateways=1,
        )
        cluster = Cluster(
            self,
            "Cluster",
            vpc=vpc,
            container_insights_v2=ContainerInsights.ENHANCED,
        )

        infrastructure_role = Role(
            self,
            "InfrastructureRole",
            assumed_by=ServicePrincipal("ecs.amazonaws.com"),
            managed_policies=[
                ManagedPolicy.from_aws_managed_policy_name(
                    "service-role/"
                    "AmazonECSInfrastructureRoleforExpressGatewayServices"
                )
            ],
        )
        infrastructure_role.assume_role_policy.add_statements(
            PolicyStatement(
                actions=["sts:TagSession"],
                principals=[ServicePrincipal("ecs.amazonaws.com")],
            )
        )
        infrastructure_policy = Policy(
            self,
            "InfrastructureControlPlanePolicy",
            statements=[
                PolicyStatement(
                    actions=[
                        "ecs:DescribeServices",
                        "ecs:UpdateService",
                    ],
                    resources=[
                        (
                            f"arn:{self.partition}:ecs:{self.region}:"
                            f"{self.account}:service/"
                            f"{cluster.cluster_name}/*"
                        )
                    ],
                ),
                PolicyStatement(
                    actions=["cloudwatch:DescribeAlarms"],
                    resources=[
                        (
                            f"arn:{self.partition}:cloudwatch:{self.region}:"
                            f"{self.account}:alarm:*"
                        )
                    ],
                ),
                PolicyStatement(
                    actions=["ec2:DescribeInternetGateways"],
                    resources=["*"],
                ),
            ],
        )
        infrastructure_policy.attach_to_role(infrastructure_role)

        basic_log_group = LogGroup(
            self,
            "BasicLogGroup",
            retention=RetentionDays.ONE_WEEK,
            removal_policy=RemovalPolicy.DESTROY,
        )
        basic_execution_role = Role(
            self,
            "BasicExecutionRole",
            assumed_by=ServicePrincipal("ecs-tasks.amazonaws.com"),
            managed_policies=[
                ManagedPolicy.from_aws_managed_policy_name(
                    "service-role/AmazonECSTaskExecutionRolePolicy"
                )
            ],
        )
        basic_task_role = Role(
            self,
            "BasicTaskRole",
            assumed_by=ServicePrincipal("ecs-tasks.amazonaws.com"),
        )
        basic_security_group = SecurityGroup(
            self,
            "BasicSecurityGroup",
            vpc=vpc,
            allow_all_outbound=True,
            description="Image-based Express Gateway service",
        )
        basic_security_group.add_ingress_rule(
            Peer.ipv4(vpc.vpc_cidr_block),
            Port.tcp(3000),
            "Application port from the Express-managed load balancer",
        )

        basic_service = CfnExpressGatewayService(
            self,
            "BasicExpressService",
            cluster=cluster.cluster_arn,
            cpu="512",
            memory="1024",
            execution_role_arn=basic_execution_role.role_arn,
            infrastructure_role_arn=infrastructure_role.role_arn,
            task_role_arn=basic_task_role.role_arn,
            health_check_path="/",
            network_configuration=(
                CfnExpressGatewayService.ExpressGatewayServiceNetworkConfigurationProperty(
                    subnets=[subnet.subnet_id for subnet in vpc.private_subnets],
                    security_groups=[basic_security_group.security_group_id],
                )
            ),
            primary_container=(
                CfnExpressGatewayService.ExpressGatewayContainerProperty(
                    image=("public.ecr.aws/aws-containers/" "ecsdemo-frontend:776fd50"),
                    container_port=3000,
                    aws_logs_configuration=(
                        CfnExpressGatewayService.ExpressGatewayServiceAwsLogsConfigurationProperty(
                            log_group=basic_log_group.log_group_name,
                            log_stream_prefix="basic",
                        )
                    ),
                )
            ),
            scaling_target=(
                CfnExpressGatewayService.ExpressGatewayScalingTargetProperty(
                    auto_scaling_metric="AVERAGE_CPU",
                    auto_scaling_target_value=70,
                    min_task_count=1,
                    max_task_count=4,
                )
            ),
            tags=[CfnTag(key="Blueprint", value="express-mode-basic")],
        )
        basic_service.node.add_dependency(infrastructure_policy)

        CfnOutput(
            self,
            "BasicEndpoint",
            value=basic_service.attr_endpoint,
        )
        CfnOutput(
            self,
            "BasicServiceArn",
            value=basic_service.attr_service_arn,
        )

        if not enable_custom_task_definition:
            return

        custom_log_group = LogGroup(
            self,
            "CustomLogGroup",
            retention=RetentionDays.ONE_WEEK,
            removal_policy=RemovalPolicy.DESTROY,
        )
        custom_task = FargateTaskDefinition(
            self,
            "CustomTaskDefinition",
            cpu=512,
            memory_limit_mib=1024,
        )
        custom_task_log_policy = custom_task.task_role.add_to_principal_policy(
            PolicyStatement(
                actions=[
                    "logs:CreateLogStream",
                    "logs:DescribeLogStreams",
                    "logs:PutLogEvents",
                ],
                resources=[custom_log_group.log_group_arn],
            )
        )

        web = custom_task.add_container(
            "Web",
            container_name="Main",
            image=ContainerImage.from_registry(
                "public.ecr.aws/aws-containers/" "ecsdemo-frontend:776fd50"
            ),
            cpu=384,
            memory_reservation_mib=512,
            health_check=HealthCheck(
                command=[
                    "CMD-SHELL",
                    "curl -fsS http://localhost:3000/ || exit 1",
                ],
                interval=Duration.seconds(15),
                retries=3,
                start_period=Duration.seconds(20),
                timeout=Duration.seconds(5),
            ),
            logging=LogDrivers.firelens(
                options={
                    "Name": "cloudwatch",
                    "region": self.region,
                    "log_group_name": custom_log_group.log_group_name,
                    "log_stream_prefix": "web-",
                    "auto_create_group": "false",
                }
            ),
            readonly_root_filesystem=False,
        )
        web.add_port_mappings(
            PortMapping(
                name="web",
                container_port=3000,
            )
        )

        log_router = custom_task.add_firelens_log_router(
            "LogRouter",
            container_name="log-router",
            image=ContainerImage.from_registry(
                "public.ecr.aws/aws-observability/" "aws-for-fluent-bit:3.4.10"
            ),
            firelens_config=FirelensConfig(type=FirelensLogRouterType.FLUENTBIT),
            logging=LogDrivers.aws_logs(
                stream_prefix="router",
                log_group=custom_log_group,
            ),
            memory_reservation_mib=128,
            user="0",
        )
        # Keep Main first when ECS registers the FireLens task definition.
        web.add_container_dependencies(
            ContainerDependency(
                container=log_router,
                condition=ContainerDependencyCondition.START,
            )
        )

        custom_security_group = SecurityGroup(
            self,
            "CustomSecurityGroup",
            vpc=vpc,
            allow_all_outbound=True,
            description="Custom-task-definition Express Gateway service",
        )
        custom_security_group.add_ingress_rule(
            Peer.ipv4(vpc.vpc_cidr_block),
            Port.tcp(3000),
            "Application port from the Express-managed load balancer",
        )
        custom_service = CfnExpressGatewayService(
            self,
            "CustomExpressService",
            cluster=cluster.cluster_arn,
            infrastructure_role_arn=infrastructure_role.role_arn,
            task_definition_arn=custom_task.task_definition_arn,
            health_check_path="/",
            network_configuration=(
                CfnExpressGatewayService.ExpressGatewayServiceNetworkConfigurationProperty(
                    subnets=[subnet.subnet_id for subnet in vpc.private_subnets],
                    security_groups=[custom_security_group.security_group_id],
                )
            ),
            scaling_target=(
                CfnExpressGatewayService.ExpressGatewayScalingTargetProperty(
                    auto_scaling_metric="AVERAGE_CPU",
                    auto_scaling_target_value=70,
                    min_task_count=1,
                    max_task_count=4,
                )
            ),
            tags=[CfnTag(key="Blueprint", value="express-mode-custom")],
        )
        custom_service.node.add_dependency(infrastructure_policy)
        custom_service.node.add_dependency(custom_task_log_policy.policy_dependable)
        execution_policy = custom_task.execution_role.node.try_find_child(
            "DefaultPolicy"
        )
        if execution_policy is not None:
            custom_service.node.add_dependency(execution_policy)

        CfnOutput(
            self,
            "CustomEndpoint",
            value=custom_service.attr_endpoint,
        )
        CfnOutput(
            self,
            "CustomServiceArn",
            value=custom_service.attr_service_arn,
        )
