import aws_cdk as core
import aws_cdk.assertions as assertions
import pytest

from examples.core_infra.app import CoreInfrastructureStack


@pytest.fixture
def template():
    app = core.App()
    stack = CoreInfrastructureStack(app, "cdk-ecs-blueprints")
    template = assertions.Template.from_stack(stack)
    return template


def test_core_infra_has_vpc(template):
    template.has_resource(
        "AWS::EC2::VPC",
        {
            "Type": "AWS::EC2::VPC",
            "Properties": {
                "CidrBlock": "10.0.0.0/24",
                "EnableDnsHostnames": True,
                "EnableDnsSupport": True,
                "InstanceTenancy": "default",
                "Tags": [
                    {
                    "Key": "Name",
                    "Value": "cdk-ecs-blueprints/Ecs-Vpc"
                    }
                ]
            }
        }
    )


def test_core_infra_has_cluster(template):
    template.has_resource(
        "AWS::ECS::Cluster",
        {
            "Type": "AWS::ECS::Cluster",
            "Properties": {
                "ClusterName": "ecs-cluster",
                "ClusterSettings": [
                    {
                    "Name": "containerInsights",
                    "Value": "enabled"
                    }
                ]
            }
        }
    )
