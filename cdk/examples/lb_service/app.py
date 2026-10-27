from aws_cdk import App, Environment
from dotenv import dotenv_values
from lib.lb_service_stack import LoadBalancedServiceStack
from lib.lb_service_stack_props import LoadBalancedServiceStackProps


app = App()
stack_props = LoadBalancedServiceStackProps(**dotenv_values(".env"))

stack = LoadBalancedServiceStack(
    app,
    "LoadBalancedService",
    stack_props=stack_props,
    env=Environment(
        account=stack_props.account_number,
        region=stack_props.aws_region,
    ),
)

app.synth()
