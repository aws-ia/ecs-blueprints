import aws_cdk as core
import aws_cdk.assertions as assertions
import pytest
from examples.core_infra.core_infra_stack import CoreInfraStack
from examples.lib.core_infrastructure_construct import CoreInfrastructureProps


@pytest.fixture
def template():
    app = core.App()
    stack = CoreInfraStack(app, "cdk-ecs-blueprints", CoreInfrastructureProps())
    template = assertions.Template.from_stack(stack)
    return template


def test_core_infra_has_vpc(template):
    template.has_resource(
        "AWS::EC2::VPC",
        {
            "Type": "AWS::EC2::VPC",
            "Properties": {
                "CidrBlock": "10.0.0.0/16",
                "EnableDnsHostnames": True,
                "EnableDnsSupport": True,
                "InstanceTenancy": "default",
                "Tags": [
                    {
                        "Key": "Name",
                        "Value": "cdk-ecs-blueprints/CoreInfrastructureConstruct/EcsVpc",
                    }
                ],
            },
        },
    )


def test_core_infra_has_cluster(template):
    template.has_resource(
        "AWS::ECS::Cluster",
        {
            "Type": "AWS::ECS::Cluster",
            "Properties": {
                "ClusterName": "a_core_stack",
                "ClusterSettings": [{"Name": "containerInsights", "Value": "enabled"}],
            },
        },
    )
