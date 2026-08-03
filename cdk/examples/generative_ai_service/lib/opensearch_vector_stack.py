from aws_cdk import CfnOutput, Stack
from aws_cdk.aws_opensearchserverless import (
    CfnSecurityPolicy,
    CfnCollection,
    CfnVpcEndpoint,
)
from aws_cdk.aws_ec2 import Peer, Port, SecurityGroup, SubnetType, Vpc
from constructs import Construct
from aws_cdk.aws_ssm import StringParameter

class OpenSearchVectorEngineStack(Stack):
    def __init__(
        self,
        scope: Construct,
        id: str,
        vpc: Vpc,
        **kwargs
    ) -> None:

        super().__init__(scope, id, **kwargs)

        # opensearch variables
        self.collection_name = "movie"
        collection_name = self.collection_name

        endpoint_security_group = SecurityGroup(
            self,
            "OpenSearchServerlessEndpointSecurityGroup",
            vpc=vpc,
            allow_all_outbound=True,
        )
        endpoint_security_group.add_ingress_rule(
            Peer.ipv4(vpc.vpc_cidr_block),
            Port.tcp(443),
            "Allow HTTPS from the VPC",
        )
        self.vpc_endpoint = CfnVpcEndpoint(
            self,
            "OpenSearchServerlessVpcEndpoint",
            name=f"{collection_name}-endpoint",
            security_group_ids=[endpoint_security_group.security_group_id],
            subnet_ids=vpc.select_subnets(
                subnet_type=SubnetType.PRIVATE_WITH_EGRESS
            ).subnet_ids,
            vpc_id=vpc.vpc_id,
        )

        # network access
        self.network_policy = CfnSecurityPolicy(
            self,
            f'sample-vectordb-nw-{collection_name}',
            name=f'sample-vectordb-nw-{collection_name}',
            type='network',
            policy=self.to_json_string([
                {
                    "Rules": [
                        {
                            "ResourceType": "collection",
                            "Resource": [f"collection/{collection_name}"],
                        },
                        {
                            "ResourceType": "dashboard",
                            "Resource": [f"collection/{collection_name}"],
                        },
                    ],
                    "AllowFromPublic": False,
                    "SourceVPCEs": [self.vpc_endpoint.attr_id],
                }
            ]),
        )

        # encryption
        self.encryption_policy = CfnSecurityPolicy(
            self,
            f'sample-vectordb-encrypt-{collection_name}',
            name=f'sample-vectordb-encryption-{collection_name}',
            type='encryption',
            policy="""{\"Rules\":[{\"ResourceType\":\"collection\",\"Resource\":[\"collection/"""+ collection_name +"""\"]}],\"AWSOwnedKey\":true}"""
        )

        # opensearch serverless for vector search
        self.cfn_collection = CfnCollection(
            self,
            f"vector_db_collection_{collection_name}",
            name=f"{collection_name}",
            # the properties below are optional
            description="Serverless vector db",
            type="VECTORSEARCH"
        )

        self.cfn_collection.add_dependency(self.encryption_policy)
        self.cfn_collection.add_dependency(self.network_policy)

        CfnOutput(
            self,
            f'collection_endpoint_{collection_name}',
            value=self.cfn_collection.attr_collection_endpoint,
            description='Collection Endpoint',
            export_name='collection-endpoint-url'
        )

        # Store opensearch endpoint, region code to Parameter Store
        StringParameter(self, "aoss_endpoint", parameter_name="aoss_endpoint", string_value=self.cfn_collection.attr_collection_endpoint)
        StringParameter(self, "aoss_region", parameter_name="aoss_region", string_value=self.region)
