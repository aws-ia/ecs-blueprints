from aws_cdk import App, Environment
from components.core_infrastructure_construct import CoreInfrastructureProps
from dotenv import dotenv_values
from lib.core_infra_stack import CoreInfraStack

config = dotenv_values(".env")
core_props = CoreInfrastructureProps(**config)
app = App()
core_stack = CoreInfraStack(
    app,
    "CoreInfraStack",
    core_infra_props=core_props,
    env=Environment(
        account=core_props.account_number,
        region=core_props.aws_region,
    ),
)
app.synth()
