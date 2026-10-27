import aws_cdk as cdk
from aws_cdk import assertions
from aws_cdk import aws_ec2 as ec2
from aws_cdk import aws_ecs as ecs
from aws_cdk import aws_lambda as lambda_
from data_pipeline.python.lib.data_pipeline_workflow import (
    create_data_pipeline_statemachine,
)


def test_data_pipeline_workflow_synthesizes():
    app = cdk.App()
    stack = cdk.Stack(app, "DataPipelineWorkflow")
    vpc = ec2.Vpc(stack, "Vpc", max_azs=2)
    cluster = ecs.Cluster(stack, "Cluster", vpc=vpc)
    task_definition = ecs.FargateTaskDefinition(stack, "Task")
    container = task_definition.add_container(
        "Processor",
        image=ecs.ContainerImage.from_registry(
            "public.ecr.aws/docker/library/busybox:1.37"
        ),
    )
    prepare_data = lambda_.Function(
        stack,
        "PrepareData",
        runtime=lambda_.Runtime.PYTHON_3_12,
        handler="index.handler",
        code=lambda_.Code.from_inline(
            "def handler(event, context):\n    return event\n"
        ),
    )

    create_data_pipeline_statemachine(
        stack,
        cluster,
        task_definition,
        container,
        prepare_data,
        "input-bucket",
    )

    template = assertions.Template.from_stack(stack)
    template.resource_count_is("AWS::StepFunctions::StateMachine", 1)

    state_machine = next(
        resource
        for resource in template.to_json()["Resources"].values()
        if resource["Type"] == "AWS::StepFunctions::StateMachine"
    )
    definition_parts = state_machine["Properties"]["DefinitionString"]["Fn::Join"][1]
    definition_text = "".join(
        part for part in definition_parts if isinstance(part, str)
    )

    assert definition_text.count('"Next":"Broadcast error status"') == 4
    assert '"DetailType":"Data Processing Error"' in definition_text
    assert '"Name":"FOLDERNAME","Value.$":"$.foldername"' in definition_text
