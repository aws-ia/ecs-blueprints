from aws_cdk import CfnOutput, PhysicalName, RemovalPolicy, Stack
from aws_cdk.aws_ec2 import IpAddresses, Port, Vpc
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
from aws_cdk.aws_ecs_patterns import (
    ApplicationLoadBalancedFargateService,
    ApplicationLoadBalancedTaskImageOptions,
)
from aws_cdk.aws_iam import PolicyStatement
from aws_cdk.aws_logs import LogGroup, RetentionDays
from aws_cdk.aws_servicediscovery import PrivateDnsNamespace
from constructs import Construct

from lb_service.lib.lb_service_stack_props import (
    LoadBalancedServiceStackProps,
)


class LoadBalancedServiceStack(Stack):
    def __init__(
        self,
        scope: Construct,
        construct_id: str,
        stack_props: LoadBalancedServiceStackProps,
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

        backend_log_group = LogGroup(
            self,
            "BackendLogGroup",
            retention=RetentionDays.ONE_WEEK,
            log_group_name=PhysicalName.GENERATE_IF_NEEDED,
        )
        backend_log_group.apply_removal_policy(RemovalPolicy.DESTROY)

        backend_task = FargateTaskDefinition(
            self,
            "BackendTaskDefinition",
            cpu=stack_props.task_cpu,
            memory_limit_mib=stack_props.task_memory,
        )
        backend_task.add_to_task_role_policy(
            PolicyStatement(actions=["ec2:DescribeSubnets"], resources=["*"])
        )

        backend_container = backend_task.add_container(
            "BackendContainer",
            container_name="ecsdemo-backend",
            image=ContainerImage.from_registry(
                stack_props.backend_container_image
            ),
            logging=LogDriver.aws_logs(
                stream_prefix="backend",
                log_group=backend_log_group,
            ),
        )
        backend_container.add_port_mappings(
            PortMapping(container_port=stack_props.container_port)
        )

        self.backend_service = FargateService(
            self,
            "BackendService",
            cluster=self.cluster,
            service_name=f"{stack_props.service_name}-backend",
            task_definition=backend_task,
            desired_count=max(2, stack_props.desired_count - 1),
            enable_execute_command=True,
            enable_ecs_managed_tags=True,
            circuit_breaker=DeploymentCircuitBreaker(rollback=True),
            min_healthy_percent=100,
            cloud_map_options=CloudMapOptions(
                cloud_map_namespace=self.namespace,
                name="backend",
            ),
        )

        frontend_log_group = LogGroup(
            self,
            "FrontendLogGroup",
            retention=RetentionDays.ONE_WEEK,
            log_group_name=PhysicalName.GENERATE_IF_NEEDED,
        )
        frontend_log_group.apply_removal_policy(RemovalPolicy.DESTROY)

        backend_endpoint = (
            stack_props.backend_svc_endpoint
            or f"http://backend.{stack_props.namespace_name}:"
            f"{stack_props.container_port}"
        )

        frontend = ApplicationLoadBalancedFargateService(
            self,
            "FrontendService",
            service_name=stack_props.service_name,
            cluster=self.cluster,
            cpu=stack_props.task_cpu,
            memory_limit_mib=stack_props.task_memory,
            desired_count=stack_props.desired_count,
            enable_execute_command=True,
            public_load_balancer=True,
            circuit_breaker=DeploymentCircuitBreaker(rollback=True),
            min_healthy_percent=100,
            cloud_map_options=CloudMapOptions(
                cloud_map_namespace=self.namespace,
                name=stack_props.service_name,
            ),
            task_image_options=ApplicationLoadBalancedTaskImageOptions(
                container_name=stack_props.container_name,
                image=ContainerImage.from_registry(
                    stack_props.container_image
                ),
                container_port=stack_props.container_port,
                log_driver=LogDriver.aws_logs(
                    stream_prefix="frontend",
                    log_group=frontend_log_group,
                ),
                environment={"NODEJS_URL": backend_endpoint},
            ),
            enable_ecs_managed_tags=True,
        )
        self.frontend_service = frontend.service

        self.backend_service.connections.allow_from(
            self.frontend_service,
            Port.tcp(stack_props.container_port),
            "Frontend to backend",
        )

        frontend_scaling = self.frontend_service.auto_scale_task_count(
            min_capacity=stack_props.desired_count,
            max_capacity=10,
        )
        frontend_scaling.scale_on_cpu_utilization(
            "FrontendCpuScaling",
            target_utilization_percent=50,
        )

        CfnOutput(
            self,
            "ApplicationUrl",
            value=f"http://{frontend.load_balancer.load_balancer_dns_name}",
        )
        CfnOutput(
            self,
            "BackendEndpoint",
            value=backend_endpoint,
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
