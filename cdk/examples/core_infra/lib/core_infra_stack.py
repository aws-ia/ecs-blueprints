from aws_cdk import CfnOutput, Stack
from components.core_infrastructure_construct import (
    CoreInfrastructureConstruct,
    CoreInfrastructureProps,
)
from constructs import Construct


class CoreInfraStack(Stack):
    def __init__(
        self,
        scope: Construct,
        id: str,
        core_infra_props: CoreInfrastructureProps,
        **kwargs
    ):
        super().__init__(scope, id, **kwargs)

        self.stack_props = core_infra_props
        self._core_construct = CoreInfrastructureConstruct(
            self, "CoreInfrastructureConstruct", core_infra_props=core_infra_props
        )

        CfnOutput(self, "vpc_id", value=self.vpc.vpc_id)
        CfnOutput(
            self,
            "public_subnets",
            value=str([i.subnet_id for i in self.vpc.public_subnets]),
        )
        CfnOutput(
            self,
            "private_subnets",
            value=str([i.subnet_id for i in self.vpc.private_subnets]),
        )
        CfnOutput(self, "ecs_cluster_name", value=self.ecs_cluster.cluster_name)
        CfnOutput(self, "ecs_cluster_id", value=self.ecs_cluster.cluster_arn)
        CfnOutput(
            self,
            "ecs_task_execution_role_name",
            value=self.ecs_task_execution_role.role_name,
        )
        CfnOutput(
            self,
            "ecs_task_execution_role_arn",
            value=self.ecs_task_execution_role.role_arn,
        )
        CfnOutput(
            self,
            "sd_namespaces",
            value=str(
                {
                    n.namespace_name: {"arn": n.namespace_arn, "id": n.namespace_id}
                    for n in self.private_dns_namespaces
                }
            ),
        )

    @property
    def vpc(self):
        return self._core_construct.vpc

    @property
    def ecs_cluster_name(self):
        return self._core_construct.ecs_cluster_name

    @property
    def ecs_task_execution_role(self):
        return self._core_construct.ecs_task_execution_role

    @property
    def ecs_task_execution_role_arn(self):
        return self._core_construct.ecs_task_execution_role_arn

    @property
    def ecs_cluster(self):
        return self._core_construct.ecs_cluster

    @property
    def vpc_id(self):
        return self._core_construct.vpc_id

    @property
    def private_dns_namespaces(self):
        return self._core_construct.private_dns_namespaces

    def validate_stack_props(self):
        if (
            self.stack_props.account_number in ["<ACCOUNT_NUMBER>", None]
            or self.stack_props.aws_region == "<REGION>"
        ):
            raise ValueError(
                "Environment values need to be set for account_number, aws_region"
            )
