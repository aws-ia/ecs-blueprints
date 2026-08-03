import json

import aws_cdk as cdk
from aws_cdk import aws_ec2 as ec2
from aws_cdk import aws_iam as iam
from aws_cdk import aws_servicediscovery as servicediscovery
from aws_cdk.assertions import Match, Template

from event_bridge.lib.event_asso_service_stack import EventAssociatedServiceStack
from event_bridge.lib.event_asso_service_stack_props import (
    EventAssociatedServiceStackProps,
)


ENV = cdk.Environment(account="111122223333", region="us-west-2")


def build_stack():
    app = cdk.App()
    support = cdk.Stack(app, "Support", env=ENV)
    vpc = ec2.Vpc(support, "Vpc", max_azs=2)
    namespace = servicediscovery.PrivateDnsNamespace(
        support,
        "Namespace",
        name="example.local",
        vpc=vpc,
    )
    execution_role = iam.Role(
        support,
        "ExecutionRole",
        assumed_by=iam.ServicePrincipal("ecs-tasks.amazonaws.com"),
    )

    props = EventAssociatedServiceStackProps(
        account_number=ENV.account,
        aws_region=ENV.region,
        container_image="nginx",
        container_name="sample-container",
        container_port="80",
        desired_count="1",
        ecs_cluster_name="example-cluster",
        ecs_task_execution_role_arn=execution_role.role_arn,
        namespace_name="example.local",
        service_name="sample-service",
    )
    props.vpc = vpc
    props.sd_namespace = namespace

    stack = EventAssociatedServiceStack(
        app, "EventBridgeAssociatedService", props, env=ENV
    )
    return Template.from_stack(stack)


def test_metric_filter_counts_both_stop_codes():
    template = build_stack()
    template.has_resource_properties(
        "AWS::Logs::MetricFilter",
        {
            "FilterPattern": Match.string_like_regexp(
                r".*TaskFailedToStart.*\|\|.*EssentialContainerExited.*"
            ),
        },
    )


def test_service_is_private_with_vpc_scoped_ingress():
    template = build_stack()

    template.has_resource_properties(
        "AWS::ECS::Service",
        {
            "NetworkConfiguration": {
                "AwsvpcConfiguration": {"AssignPublicIp": "DISABLED"},
            },
        },
    )

    ingress_rules = [
        rule
        for group in template.find_resources("AWS::EC2::SecurityGroup").values()
        for rule in group["Properties"].get("SecurityGroupIngress", [])
    ] + [
        resource["Properties"]
        for resource in template.find_resources(
            "AWS::EC2::SecurityGroupIngress"
        ).values()
    ]
    assert ingress_rules, "expected at least one ingress rule"
    assert "0.0.0.0/0" not in json.dumps(ingress_rules)
