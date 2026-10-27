import aws_cdk as core
import aws_cdk.assertions as assertions
from express_mode.lib.express_mode_stack import ExpressModeStack


def test_express_mode_has_basic_and_custom_variants():
    app = core.App()
    stack = ExpressModeStack(
        app,
        "express-mode-test",
        enable_custom_task_definition=True,
    )
    template = assertions.Template.from_stack(stack)

    template.resource_count_is("AWS::ECS::ExpressGatewayService", 2)
    template.has_resource_properties(
        "AWS::ECS::ExpressGatewayService",
        {
            "PrimaryContainer": {
                "ContainerPort": 3000,
                "Image": ("public.ecr.aws/aws-containers/" "ecsdemo-frontend:776fd50"),
            },
        },
    )
    template.has_resource_properties(
        "AWS::ECS::ExpressGatewayService",
        {
            "TaskDefinitionArn": {
                "Ref": assertions.Match.string_like_regexp("CustomTaskDefinition")
            },
            "HealthCheckPath": "/",
        },
    )


def test_custom_variant_is_disabled_by_default():
    app = core.App()
    stack = ExpressModeStack(app, "express-mode-default-test")
    template = assertions.Template.from_stack(stack)

    template.resource_count_is("AWS::ECS::ExpressGatewayService", 1)
    template.resource_count_is("AWS::ECS::TaskDefinition", 0)


def test_custom_task_definition_has_firelens_and_health_check():
    app = core.App()
    stack = ExpressModeStack(
        app,
        "express-mode-task-test",
        enable_custom_task_definition=True,
    )
    template = assertions.Template.from_stack(stack)

    template.has_resource_properties(
        "AWS::ECS::TaskDefinition",
        {
            "ContainerDefinitions": assertions.Match.array_with(
                [
                    assertions.Match.object_like(
                        {
                            "Name": "Main",
                            "HealthCheck": {
                                "Command": [
                                    "CMD-SHELL",
                                    ("curl -fsS " "http://localhost:3000/ || exit 1"),
                                ]
                            },
                        }
                    ),
                    assertions.Match.object_like(
                        {
                            "FirelensConfiguration": {
                                "Type": "fluentbit",
                            }
                        }
                    ),
                ]
            )
        },
    )

    resources = template.to_json()["Resources"]
    task_definition = next(
        resource
        for resource in resources.values()
        if resource["Type"] == "AWS::ECS::TaskDefinition"
    )
    properties = task_definition["Properties"]
    containers = properties["ContainerDefinitions"]

    assert properties["NetworkMode"] == "awsvpc"
    assert properties["RequiresCompatibilities"] == ["FARGATE"]
    assert containers[0]["Name"] == "Main"
    assert containers[0]["PortMappings"] == [
        {
            "ContainerPort": 3000,
            "Protocol": "tcp",
            "Name": "web",
        }
    ]
    assert containers[0]["DependsOn"] == [
        {
            "ContainerName": "log-router",
            "Condition": "START",
        }
    ]
    assert containers[1]["Name"] == "log-router"


def test_express_services_wait_for_required_policies():
    app = core.App()
    stack = ExpressModeStack(
        app,
        "express-mode-dependency-test",
        enable_custom_task_definition=True,
    )
    resources = assertions.Template.from_stack(stack).to_json()["Resources"]

    infrastructure_policy = next(
        logical_id
        for logical_id, resource in resources.items()
        if resource["Type"] == "AWS::IAM::Policy"
        and "InfrastructureControlPlanePolicy" in logical_id
    )
    custom_service = next(
        resource
        for logical_id, resource in resources.items()
        if resource["Type"] == "AWS::ECS::ExpressGatewayService"
        and "CustomExpressService" in logical_id
    )
    basic_service = next(
        resource
        for logical_id, resource in resources.items()
        if resource["Type"] == "AWS::ECS::ExpressGatewayService"
        and "BasicExpressService" in logical_id
    )
    custom_properties = custom_service["Properties"]
    assert custom_properties["ScalingTarget"]["MinTaskCount"] == 1
    assert custom_properties["ScalingTarget"]["MaxTaskCount"] == 4
    assert {
        "PrimaryContainer",
        "Cpu",
        "Memory",
        "ExecutionRoleArn",
        "TaskRoleArn",
    }.isdisjoint(custom_properties)

    custom_task_policy = next(
        resource
        for logical_id, resource in resources.items()
        if resource["Type"] == "AWS::IAM::Policy"
        and "TaskRoleDefaultPolicy" in logical_id
    )
    log_resource = custom_task_policy["Properties"]["PolicyDocument"]["Statement"][0][
        "Resource"
    ]
    assert "Fn::GetAtt" in log_resource

    infrastructure_role = next(
        logical_id
        for logical_id, resource in resources.items()
        if resource["Type"] == "AWS::IAM::Role" and "InfrastructureRole" in logical_id
    )

    assert infrastructure_policy in custom_service["DependsOn"]
    assert infrastructure_policy in basic_service["DependsOn"]
    assert {"Ref": infrastructure_role} in resources[infrastructure_policy][
        "Properties"
    ]["Roles"]
    assert any(
        "TaskRoleDefaultPolicy" in dependency
        for dependency in custom_service["DependsOn"]
    )
    assert any(
        "ExecutionRoleDefaultPolicy" in dependency
        for dependency in custom_service["DependsOn"]
    )

    policy_actions = {
        action
        for statement in resources[infrastructure_policy]["Properties"][
            "PolicyDocument"
        ]["Statement"]
        for action in (
            statement["Action"]
            if isinstance(statement["Action"], list)
            else [statement["Action"]]
        )
    }
    assert {
        "ecs:DescribeServices",
        "ecs:UpdateService",
        "cloudwatch:DescribeAlarms",
        "ec2:DescribeInternetGateways",
    }.issubset(policy_actions)
