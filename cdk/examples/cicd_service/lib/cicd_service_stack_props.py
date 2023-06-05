from aws_cdk import StackProps
from aws_cdk.aws_ec2 import Vpc
from aws_cdk.aws_servicediscovery import PrivateDnsNamespace


class CICDServiceStackProps(StackProps):
    def __init__(
        self,
        account_number=None,
        aws_region=None,
        az_count=None,
        buildspec_path=None,
        container_image=None,
        container_name=None,
        container_port="80",
        desired_count="2",
        deploy_core_stack=True,
        ecr_repository_name=None,
        ecs_cluster_name=None,
        ecs_task_execution_role_arn=None,
        enable_nat_gw=None,
        create_ec2_instance=False,
        folder_path=None,
        github_token_secret_name=None,
        namespaces="a",
        namespace_name=None,
        namespace_arn=None,
        namespace_id=None,
        repository_owner=None,
        repository_name=None,
        repository_branch=None,
        service_name=None,
        task_cpu="256",
        task_memory="512",
        vpc_name=None,
        vpc_cidr=None,
    ):
        self.account_number = account_number
        self.aws_region = aws_region
        self.buildspec_path = buildspec_path
        self.container_image = container_image
        self.container_name = container_name
        self.container_port = int(container_port)
        self.desired_count = int(desired_count)
        self.ecr_repository_name = ecr_repository_name
        self.ecs_cluster_name = ecs_cluster_name
        self.ecs_task_execution_role_arn = ecs_task_execution_role_arn
        self.folder_path = folder_path
        self.github_token_secret_name = github_token_secret_name
        self.namespaces = namespaces.split(",")
        self.namespace_name = namespace_name
        self.namespace_arn = namespace_arn
        self.namespace_id = namespace_id
        self.repository_owner = repository_owner
        self.repository_name = repository_name
        self.repository_branch = repository_branch
        self.service_name = service_name
        self.task_cpu = int(task_cpu)
        self.task_memory = int(task_memory)
        self.vpc_name = vpc_name

        self._vpc = None
        self._sd_namespace = None

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
        self.namespace_id = value.namespace_arn
