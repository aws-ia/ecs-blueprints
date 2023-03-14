from aws_cdk import PhysicalName, Stack
from aws_cdk.aws_ec2 import Vpc, Peer, Port
from aws_cdk.aws_ecs import CloudMapOptions, Cluster, ContainerImage, LogDriver, TaskDefinition, Compatibility, FargateService, PortMapping
from aws_cdk.aws_iam import Role, PolicyStatement
from aws_cdk.aws_logs import LogGroup, RetentionDays
from aws_cdk.aws_servicediscovery import PrivateDnsNamespace
from backend_service.lib.backend_service_stack_props import BackendServiceStackProps


class BackendServiceStack(Stack):
    def __init__(
        self,
        scope: Stack,
        id: str,
        backend_service_stack_prop: BackendServiceStackProps,
        **kwargs
    ):
        super().__init__(scope, id, **kwargs)

        self.stack_props = backend_service_stack_prop
        self._ecs_cluster = None
        self._ecs_task_execution_role = None
        self._vpc = self.stack_props.vpc if self.stack_props.vpc else None
        self._sd_namespace = (
            self.stack_props.sd_namespace if self.stack_props.sd_namespace else None
        )

        log_group = LogGroup(
            self,
            "BackendServiceLogGroup",
            retention=RetentionDays.ONE_WEEK,
            log_group_name=PhysicalName.GENERATE_IF_NEEDED,
        )

        fargate_task_def = TaskDefinition(
            self,
            self.stack_props.container_name,
            compatibility=Compatibility.FARGATE,
            cpu=self.stack_props.task_cpu,
            memory_mib=self.stack_props.task_memory,
            execution_role=self.ecs_task_execution_role,
        )

        fargate_task_def.add_to_task_role_policy(
            PolicyStatement(
                actions=["ec2:DescribeSubnets"], resources=["*"]
            )
        )

        container = fargate_task_def.add_container(
            "task-container",
            image=ContainerImage.from_registry(
                self.stack_props.container_image
            ),
            container_name=self.stack_props.container_name,
            cpu=int(self.stack_props.task_cpu),
            memory_reservation_mib=int(self.stack_props.task_memory),
            logging=LogDriver.aws_logs(
                stream_prefix="ecs",
                log_group=log_group,
            ),
        )

        container.add_port_mappings(
            PortMapping(
                container_port=self.stack_props.container_port
            )
        )
        self.fargate_service = FargateService(
            self,
            "BackendFargateService",
            service_name=self.stack_props.service_name,
            task_definition=fargate_task_def,
            enable_execute_command=True,
            cluster=self.ecs_cluster,
            desired_count=self.stack_props.desired_count,
            cloud_map_options=CloudMapOptions(
                cloud_map_namespace=self.sd_namespace,
                name=self.stack_props.service_name,
            ),
            enable_ecs_managed_tags=True
        )

        self.fargate_service.connections.allow_from(
            Peer.ipv4(self.vpc.vpc_cidr_block),
            Port.all_tcp(),
        )

        self.fargate_service.connections.allow_from_any_ipv4(Port.tcp(self.stack_props.container_port))

        autoscale = self.fargate_service.auto_scale_task_count(
            min_capacity=3, max_capacity=10
        )

        autoscale.scale_on_cpu_utilization(
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
