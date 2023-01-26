from aws_cdk import App, Stack
from dotenv import dotenv_values
from lib.core_infra import CoreInfraProps, CoreInfrastructureConstruct

config = dotenv_values(".env")

core_props = CoreInfraProps(**config)
app = App()
core_stack = Stack(app, "CoreInfraStack")
CoreInfrastructureConstruct(
    core_stack, "CoreInfraConstruct", core_infra_props=core_props
)

app.synth()
