import json
from pathlib import Path

import aws_cdk as cdk
from aws_cdk import aws_ec2 as ec2
from aws_cdk import aws_ecs as ecs
from aws_cdk import aws_iam as iam
from aws_cdk import aws_servicediscovery as servicediscovery

from generative_ai_rag.lib.gen_ai_rag_stack import GenAIRagServiceStack
from generative_ai_rag.lib.gen_ai_rag_stack_props import (
    GenAIRagServiceStackProps,
)
from generative_ai_service.lib.gen_ai_service_stack import GenAIServiceStack
from generative_ai_service.lib.gen_ai_service_stack_props import (
    GenAIServiceStackProps,
)


EXAMPLES = Path(__file__).resolve().parents[1] / "examples"
ENV = cdk.Environment(account="111122223333", region="us-west-2")


def support_resources(app):
    stack = cdk.Stack(app, "Support", env=ENV)
    vpc = ec2.Vpc(stack, "Vpc", max_azs=2, nat_gateways=0)
    namespace = servicediscovery.PrivateDnsNamespace(
        stack,
        "Namespace",
        name="example.local",
        vpc=vpc,
    )
    cluster = ecs.Cluster(stack, "Cluster", vpc=vpc)
    execution_role = iam.Role(
        stack,
        "ExecutionRole",
        assumed_by=iam.ServicePrincipal("ecs-tasks.amazonaws.com"),
    )
    return vpc, namespace, cluster, execution_role


def policy_statements(template):
    policies = template.find_resources("AWS::IAM::Policy")
    return [
        statement
        for policy in policies.values()
        for statement in policy["Properties"]["PolicyDocument"]["Statement"]
    ]


def test_gen_ai_service_uses_exact_backend_resources(monkeypatch):
    monkeypatch.chdir(EXAMPLES / "generative_ai_service")
    app = cdk.App()
    vpc, namespace, cluster, execution_role = support_resources(app)
    props = GenAIServiceStackProps(
        account_number=ENV.account,
        aws_region=ENV.region,
        container_name="web",
        container_port="80",
        desired_count="1",
        ecs_cluster_name=cluster.cluster_name,
        ecs_task_execution_role_arn=execution_role.role_arn,
        namespace_name="example.local",
        service_name="gen-ai-service",
        sagemaker_endpoint_names="endpoint-one,endpoint-two",
    )
    props.vpc = vpc
    props.sd_namespace = namespace

    stack = GenAIServiceStack(app, "GenAIService", props, env=ENV)
    collection_arn = (
        "arn:aws:aoss:us-west-2:111122223333:collection/collection-id"
    )
    stack.grant_aoss_access(collection_arn, "movie")

    template = cdk.assertions.Template.from_stack(stack)
    rendered_statements = json.dumps(policy_statements(template))
    assert "endpoint/endpoint-one" in rendered_statements
    assert "endpoint/endpoint-two" in rendered_statements
    assert collection_arn in rendered_statements
    assert "endpoint/*" not in rendered_statements
    assert "collection/*" not in rendered_statements

    access_policies = template.find_resources(
        "AWS::OpenSearchServerless::AccessPolicy"
    )
    rendered_access = json.dumps(access_policies)
    assert "aoss:ReadDocument" in rendered_access
    assert "aoss:WriteDocument" in rendered_access
    assert '"aoss:*"' not in rendered_access


def test_gen_ai_rag_uses_exact_knowledge_base(monkeypatch):
    monkeypatch.chdir(EXAMPLES / "generative_ai_rag")
    app = cdk.App()
    vpc, namespace, cluster, execution_role = support_resources(app)
    props = GenAIRagServiceStackProps(
        account_number=ENV.account,
        aws_region=ENV.region,
        container_name="web",
        container_port="80",
        desired_count="1",
        ecs_cluster_name=cluster.cluster_name,
        ecs_task_execution_role_arn=execution_role.role_arn,
        knowledge_base_id="ABCDEFGHIJ",
        namespace_name="example.local",
        service_name="gen-ai-rag-service",
    )
    props.vpc = vpc
    props.sd_namespace = namespace

    stack = GenAIRagServiceStack(app, "GenAIRagService", props, env=ENV)
    template = cdk.assertions.Template.from_stack(stack)
    rendered_statements = json.dumps(policy_statements(template))
    assert "knowledge-base/ABCDEFGHIJ" in rendered_statements
    assert "knowledge-base/*" not in rendered_statements
