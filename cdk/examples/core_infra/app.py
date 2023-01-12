#!/usr/bin/env python3
import os

import aws_cdk as cdk
from aws_cdk import (
    Stack,
    CfnOutput,
    RemovalPolicy,
    aws_logs as logs,
    aws_ec2 as ec2,
    aws_ecs as ecs,
    aws_iam as iam,
    aws_servicediscovery as servicediscovery,
)
from constructs import Construct

app = cdk.App()


class CoreInfrastructureStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        if self.node.try_get_context("enable_nat_gw"):
            nat_gateways = self.node.try_get_context("number_of_azs")
        else:
            nat_gateways = 0

        cidr_block = self.node.try_get_context("vpc_cidr")
        if cidr_block is None:
            cidr_block = "10.0.0.0/16"

        vpc = ec2.Vpc(
            self,
            "Ecs-Vpc",
            ip_addresses=ec2.IpAddresses.cidr(cidr_block),
            max_azs=self.node.try_get_context("number_of_azs"),
            nat_gateways=nat_gateways,
        )

        log_group = logs.LogGroup(
            self,
            "cloudwatch_log_group",
            log_group_name=f"/aws/ecs/{self.node.try_get_context('core_stack_name')}",
            retention=logs.RetentionDays.ONE_WEEK,
            removal_policy=RemovalPolicy.DESTROY
        )

        execute_command_configuration = ecs.ExecuteCommandConfiguration(
            logging=ecs.ExecuteCommandLogging.OVERRIDE,
            log_configuration=ecs.ExecuteCommandLogConfiguration(
                cloud_watch_log_group=log_group
            ),
        )

        cluster = ecs.Cluster(
            self,
            "ECS-Cluster",
            cluster_name=self.node.try_get_context("core_stack_name"),
            vpc=vpc,
            container_insights=True,
            execute_command_configuration=execute_command_configuration,
        )

        namespaces = self.node.try_get_context("namespaces")

        service_discovery = {}

        for namespace in namespaces:
            private_dns_namespace = servicediscovery.PrivateDnsNamespace(
                self,
                f"{namespace}-namespace",
                vpc=vpc,
                name=f"{namespace}.{cluster.cluster_name}.local",
            )
            service_discovery[
                f"{namespace}.{self.node.try_get_context('core_stack_name')}.local"
            ] = {}
            service_discovery[
                f"{namespace}.{self.node.try_get_context('core_stack_name')}.local"
            ]["arn"] = private_dns_namespace.namespace_arn
            service_discovery[
                f"{namespace}.{self.node.try_get_context('core_stack_name')}.local"
            ]["name"] = private_dns_namespace.namespace_name
            service_discovery[
                f"{namespace}.{self.node.try_get_context('core_stack_name')}.local"
            ]["id"] = private_dns_namespace.namespace_id

        task_execution_role = iam.Role(
            self,
            "FargateContainerRole",
            assumed_by=iam.ServicePrincipal("ecs-tasks.amazonaws.com"),
            managed_policies=[
                iam.ManagedPolicy.from_aws_managed_policy_name(
                    "service-role/AmazonECSTaskExecutionRolePolicy"
                )
            ],
        )

        cluster_outputs = {"SECGRPS": str(cluster.connections.security_groups)}

        if cluster.connections.security_groups:
            cluster_outputs["SECGRPS"] = str(
                [
                    x.security_group_id
                    for x in cluster.connections.security_groups
                ][0]
            )

        # All Outputs required for other stacks to build
        CfnOutput(self, "vpc_id", value=vpc.vpc_id)
        CfnOutput(
            self,
            "public_subnets",
            value=str([i.subnet_id for i in vpc.public_subnets]),
        )
        CfnOutput(
            self,
            "private_subnets",
            value=str([i.subnet_id for i in vpc.private_subnets]),
        )
        CfnOutput(self, "ecs_cluster_name", value=cluster.cluster_name)
        CfnOutput(self, "ecs_cluster_id", value=cluster.cluster_arn)
        CfnOutput(
            self,
            "ecs_task_execution_role_name",
            value=task_execution_role.role_name,
        )
        CfnOutput(
            self,
            "ecs_task_execution_role_arn",
            value=task_execution_role.role_arn,
        )
        CfnOutput(self, "sd_namespaces", value=str(service_discovery))
        CfnOutput(
            self,
            "ecs_cluster_security_groups",
            value=cluster_outputs["SECGRPS"],
        )


CoreInfrastructureStack(
    app,
    app.node.try_get_context("core_stack_name"),
    env=cdk.Environment(region=app.node.try_get_context("aws_region")),
)

app.synth()
