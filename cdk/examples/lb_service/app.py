from os import getenv

from aws_cdk import App, Environment
from core_infra.core_infra_stack import CoreInfraProps, CoreInfrastructureStack
from lb_service_stack import LoadBalancedServiceStack, LoadBalancedServiceStackProps

app = App()

core_props = CoreInfraProps(
    core_stack_name="ecs-blueprint-infra",
    aws_region="us-east-2",
    namespaces=["default", "myapp"],
    enable_nat_gw=True,
    vpc_cidr="10.0.23.0/16",
)

core_stack = CoreInfrastructureStack(
    app,
    "CoreStackForLBService",
    core_infra_props=core_props,
    env=Environment(
        account=getenv("CDK_DEFAULT_ACCOUNT"),
        region=core_props.aws_region,
    ),
)

lb_stack_props = LoadBalancedServiceStackProps()

lb_stack_props.namespace_name = "default.ecs-blueprint-infra.local"
lb_stack_props.namespace_arn = core_stack.sd_namespaces[lb_stack_props.namespace_name][
    "arn"
]
lb_stack_props.namespace_id = core_stack.sd_namespaces[lb_stack_props.namespace_name][
    "id"
]


lb_stack_props.ecs_cluster_name = core_stack.ecs_cluster_name
lb_stack_props.ecs_task_execution_role_arn = core_stack.ecs_task_execution_role_arn
lb_stack_props.container_name = "ecsdemo-frontend"
lb_stack_props.container_port = 3000
lb_stack_props.folder_path = "./application-code/ecsdemo-frontend/."
lb_stack_props.backend_svc_endpoint = (
    "http://ecsdemo-nodejs.default.ecs-blueprint-infra.local:3000"
)
lb_stack_props.repository_owner = "umairishaq"
lb_stack_props.repository_name = "ecs-blueprints"
lb_stack_props.repository_branch = "main"
lb_stack_props.buildspec_path = (
    "./application-code/ecsdemo-frontend/templates/buildspec.yml"
)
lb_stack_props.service_name = "ecsdemo-frontend"
lb_stack_props.task_cpu = "256"
lb_stack_props.task_memory = "512"
lb_stack_props.desired_count = 3
lb_stack_props.github_token_secret_name = "ecs-github-token"
lb_stack_props.aws_region = "us-east-2"

LoadBalancedServiceStack(
    app,
    "FrontendService",
    lb_stack_props,
    core_stack,
    env=Environment(
        account=getenv("CDK_DEFAULT_ACCOUNT"),
        region=lb_stack_props.aws_region,
    ),
)

app.synth()
