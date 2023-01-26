from aws_cdk import App
from core_infra_stack import CoreInfraStack
from dotenv import dotenv_values
from lib.core_infrastructure_construct import CoreInfrastructureProps

config = dotenv_values(".env")
core_props = CoreInfrastructureProps(**config)
app = App()
core_stack = CoreInfraStack(app, "CoreInfraStack", core_infra_props=core_props)
app.synth()
