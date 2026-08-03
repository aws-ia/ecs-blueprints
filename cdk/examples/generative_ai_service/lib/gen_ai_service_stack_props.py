from aws_cdk import StackProps
from aws_cdk.aws_ec2 import Vpc
from aws_cdk.aws_servicediscovery import PrivateDnsNamespace


class GenAIServiceStackProps(StackProps):
    def __init__(
        self,
        account_number=None,
        aws_region=None,
        az_count=None,
        container_name=None,
        container_port="3000",
        desired_count="2",
        deploy_core_stack=True,
        ecs_cluster_name=None,
        ecs_task_execution_role_arn=None,
        enable_nat_gw=None,
        create_ec2_instance=False,
        namespaces="a",
        namespace_name=None,
        namespace_arn=None,
        namespace_id=None,
        service_name=None,
        sagemaker_endpoint_names=None,
        aoss_collection_arn=None,
        aoss_collection_name=None,
        task_cpu="256",
        task_memory="512",
        vpc_name=None,
        vpc_cidr=None,
    ):
        self.account_number = account_number
        self.aws_region = aws_region
        self.container_name = container_name
        self.container_port = int(container_port)
        self.desired_count = int(desired_count)
        self.ecs_cluster_name = ecs_cluster_name
        self.ecs_task_execution_role_arn = ecs_task_execution_role_arn
        self.namespaces = namespaces.split(",")
        self.namespace_name = namespace_name
        self.namespace_arn = namespace_arn
        self.namespace_id = namespace_id
        self.service_name = service_name
        self.sagemaker_endpoint_names = self._parse_list(
            sagemaker_endpoint_names
        )
        self.aoss_collection_arn = aoss_collection_arn
        self.aoss_collection_name = aoss_collection_name
        self.task_cpu = task_cpu
        self.task_memory = task_memory
        self.vpc_name = vpc_name

        self._vpc = None
        self._sd_namespace = None

    @staticmethod
    def _parse_list(value):
        if not value:
            return []
        if isinstance(value, str):
            return [item.strip() for item in value.split(",") if item.strip()]
        return list(value)

    @property
    def vpc(self):
        return self._vpc

    @vpc.setter
    def vpc(self, value: Vpc) -> None:
        self._vpc = value

    @property
    def sd_namespace(self):
        return self._sd_namespace

    @sd_namespace.setter
    def sd_namespace(self, value: PrivateDnsNamespace) -> None:
        self._sd_namespace = value
        self.namespace_arn = value.namespace_arn
        self.namespace_id = value.namespace_id
