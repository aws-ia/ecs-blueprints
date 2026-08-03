import json

import aws_cdk as cdk
from aws_cdk import aws_ec2 as ec2
from aws_cdk import aws_ecs as ecs
from aws_cdk import aws_iam as iam

from components.codestar_cicd_construct import (
    CICDConstructProps,
    CodeStarCICDConstruct,
)


def test_ecs_deploy_action_role_has_scoped_permissions():
    app = cdk.App()
    stack = cdk.Stack(
        app,
        "CicdPermissions",
        env=cdk.Environment(account="111122223333", region="us-west-2"),
    )
    vpc = ec2.Vpc(stack, "Vpc", max_azs=2, nat_gateways=0)
    cluster = ecs.Cluster(stack, "Cluster", vpc=vpc)
    execution_role = iam.Role(
        stack,
        "ExecutionRole",
        assumed_by=iam.ServicePrincipal("ecs-tasks.amazonaws.com"),
    )
    task_definition = ecs.FargateTaskDefinition(
        stack,
        "TaskDefinition",
        execution_role=execution_role,
    )
    task_definition.add_container(
        "Web",
        image=ecs.ContainerImage.from_registry(
            "public.ecr.aws/docker/library/nginx:1.27.4-alpine"
        ),
    )
    service = ecs.FargateService(
        stack,
        "Service",
        cluster=cluster,
        task_definition=task_definition,
        desired_count=0,
    )

    CodeStarCICDConstruct(
        stack,
        "Pipeline",
        CICDConstructProps(
            buildspec_path="buildspec.yml",
            container_name="Web",
            container_port="80",
            ecr_repository_name="cicd-permissions-test",
            ecs_task_execution_role=execution_role,
            fargate_service=service,
            folder_path="application-code",
            github_token_secret_name="github-token",
            repository_owner="example",
            repository_name="ecs-blueprints",
            repository_branch="main",
        ),
    )

    resources = cdk.assertions.Template.from_stack(stack).to_json()[
        "Resources"
    ]
    deploy_role_id = next(
        logical_id
        for logical_id, resource in resources.items()
        if resource["Type"] == "AWS::IAM::Role"
        and "EcsDeployActionRole" in logical_id
    )
    deploy_policies = [
        resource
        for resource in resources.values()
        if resource["Type"] == "AWS::IAM::Policy"
        and {"Ref": deploy_role_id} in resource["Properties"].get("Roles", [])
    ]
    statements = [
        statement
        for policy in deploy_policies
        for statement in policy["Properties"]["PolicyDocument"]["Statement"]
    ]

    pass_role = next(
        statement
        for statement in statements
        if statement["Action"] == "iam:PassRole"
    )
    assert pass_role["Resource"] != "*"
    assert len(pass_role["Resource"]) == 2
    assert pass_role["Condition"] == {
        "StringEquals": {
            "iam:PassedToService": "ecs-tasks.amazonaws.com",
        }
    }

    service_access = next(
        statement
        for statement in statements
        if "ecs:UpdateService" in statement["Action"]
    )
    assert service_access["Resource"] != "*"

    # Task definition actions support no resource-level permissions, so they must
    # be granted on "*"; scoping them to an ARN produces AccessDenied at deploy time.
    task_definition_access = next(
        statement
        for statement in statements
        if "ecs:RegisterTaskDefinition" in statement["Action"]
    )
    assert "ecs:DescribeTaskDefinition" in task_definition_access["Action"]
    assert task_definition_access["Resource"] == "*"

    rendered = json.dumps(statements)
    assert "task-definition/" in rendered
