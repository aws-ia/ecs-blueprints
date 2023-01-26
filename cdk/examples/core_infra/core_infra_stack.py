from aws_cdk import Stack
from constructs import Construct
from lib.core_infrastructure_construct import (
    CoreInfrastructureConstruct,
    CoreInfrastructureProps,
)


class CoreInfraStack(Stack):
    def __init__(
        self,
        scope: Construct,
        id: str,
        core_infra_props: CoreInfrastructureProps,
        **kwargs
    ):
        super().__init__(scope, id, **kwargs)

        self._core_construct = CoreInfrastructureConstruct(
            self, "CoreInfrastructureConstruct", core_infra_props=core_infra_props
        )

    @property
    def vpc(self):
        return self._core_construct.vpc
