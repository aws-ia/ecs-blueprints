import aws_cdk as core
import aws_cdk.assertions as assertions
import pytest
from core_infra.lib.core_infra_stack import CoreInfraStack
from components.core_infrastructure_construct import CoreInfrastructureProps


@pytest.fixture
def template():
    app = core.App()
    stack = CoreInfraStack(app, "cdk-ecs-blueprints", CoreInfrastructureProps())
    template = assertions.Template.from_stack(stack)
    return template


@pytest.fixture
def ec2_template():
    app = core.App()
    stack = CoreInfraStack(
        app,
        "cdk-ecs-blueprints-ec2",
        CoreInfrastructureProps(create_ec2_instance="True"),
    )
    return assertions.Template.from_stack(stack).to_json()


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
                        "Value": "a_core_stack-vpc",
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
                "ClusterSettings": [{"Name": "containerInsights", "Value": "enhanced"}],
            },
        },
    )


def test_core_infra_ec2_capacity_uses_al2023(ec2_template):
    launch_resource = next(
        resource
        for resource in ec2_template["Resources"].values()
        if resource["Type"]
        in {
            "AWS::AutoScaling::LaunchConfiguration",
            "AWS::EC2::LaunchTemplate",
        }
    )
    properties = launch_resource["Properties"]
    image_id = properties.get(
        "ImageId", properties.get("LaunchTemplateData", {}).get("ImageId")
    )
    parameter_name = image_id["Ref"]

    assert (
        ec2_template["Parameters"][parameter_name]["Default"]
        == "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id"
    )

    launch_template_data = properties.get("LaunchTemplateData", properties)
    assert launch_template_data["MetadataOptions"]["HttpTokens"] == "required"
    assert any(
        mapping["Ebs"]["Encrypted"] is True
        for mapping in launch_template_data["BlockDeviceMappings"]
    )
