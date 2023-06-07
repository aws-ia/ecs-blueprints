from aws_cdk import StackProps
from aws_cdk.aws_ec2 import Vpc
from aws_cdk.aws_servicediscovery import PrivateDnsNamespace


class DataPipelineStackProps(StackProps):
    def __init__(
        self,
        account_number=None,
        aws_region=None,
        deploy_core_stack=True,
        vpc_cidr=None,
        namespaces=None,
        enable_nat_gw=True,
        ecs_cluster_name=None,
        task_cpu="256",
        task_memory="512",
        az_count=3,
        vpc_name=None
    ):
        self.deploy_core_stack = deploy_core_stack
        self.account_number = account_number
        self.aws_region = aws_region
        self.ecs_cluster_name = ecs_cluster_name
        self.task_cpu = int(task_cpu)
        self.task_memory = int(task_memory)
        self.az_count = int(az_count)
        self.vpc_name = vpc_name
