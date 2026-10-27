from aws_cdk import StackProps

from components.config import parse_bool


class LoadBalancedServiceStackProps(StackProps):
    def __init__(
        self,
        account_number=None,
        aws_region=None,
        az_count="2",
        backend_container_image="public.ecr.aws/aws-containers/ecsdemo-nodejs:c3e96da",
        backend_svc_endpoint=None,
        container_image="public.ecr.aws/aws-containers/ecsdemo-frontend:776fd50",
        container_name="ecsdemo-frontend",
        container_port="3000",
        desired_count="3",
        ecs_cluster_name="ecs-blueprint-lb-service",
        enable_nat_gw="True",
        namespace_name="default.ecs-blueprint-lb-service.local",
        service_name="ecsdemo-frontend",
        task_cpu="256",
        task_memory="512",
        vpc_cidr="10.20.0.0/16",
    ):
        self.account_number = account_number
        self.aws_region = aws_region
        self.az_count = int(az_count)
        self.backend_container_image = backend_container_image
        self.backend_svc_endpoint = backend_svc_endpoint
        self.container_image = container_image
        self.container_name = container_name
        self.container_port = int(container_port)
        self.desired_count = int(desired_count)
        self.ecs_cluster_name = ecs_cluster_name
        self.enable_nat_gw = parse_bool(enable_nat_gw)
        self.namespace_name = namespace_name
        self.service_name = service_name
        self.task_cpu = int(task_cpu)
        self.task_memory = int(task_memory)
        self.vpc_cidr = vpc_cidr
