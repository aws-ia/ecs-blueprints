from aws_cdk import App, Environment
from dotenv import dotenv_values
from lib.backend_service_stack import BackendServiceStack
from lib.backend_service_stack_props import BackendServiceStackProps


app = App()
stack_props = BackendServiceStackProps(**dotenv_values(".env"))

stack = BackendServiceStack(
    app,
    "BackendService",
    stack_props=stack_props,
    env=Environment(
        account=stack_props.account_number,
        region=stack_props.aws_region,
    ),
)

app.synth()
