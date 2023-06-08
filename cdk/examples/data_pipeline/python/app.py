#!/usr/bin/env python3
import os
import aws_cdk as cdk
from distutils import util

from components.core_infrastructure_construct import CoreInfrastructureProps
from core_infra.lib.core_infra_stack import CoreInfraStack
from dotenv import dotenv_values

from lib.data_pipeline_stack import DataPipelineStack
from lib.data_pipeline_stack_props import DataPipelineStackProps


app = cdk.App()

env_config = dotenv_values(".env")

deploy_core = bool(util.strtobool(env_config["deploy_core_stack"]))

data_pipeline_stack_props = DataPipelineStackProps(**env_config)

if deploy_core:
    core_config = {
        i
        for i in list(env_config.items())
        if i[0] in CoreInfrastructureProps().__dict__.keys()
    }
    core_props = CoreInfrastructureProps(**dict(core_config))
    core_stack = CoreInfraStack(
        app,
        "CoreInfraStack",
        core_infra_props=core_props,
        env=cdk.Environment(
            account=core_props.account_number,
            region=core_props.aws_region,
        ),
    )
    data_pipeline_stack_props.ecs_cluster_name = core_stack.ecs_cluster_name

data_pipeline_stack = DataPipelineStack(app,
    "DataPipelineBlueprintStack",
    data_pipeline_stack_props,
    env=cdk.Environment(
        account=data_pipeline_stack_props.account_number,
        region=data_pipeline_stack_props.aws_region,
    ),
    )

data_pipeline_stack.validate_stack_props()
app.synth()
