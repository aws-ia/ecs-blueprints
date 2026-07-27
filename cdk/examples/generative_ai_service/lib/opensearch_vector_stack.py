from aws_cdk import CfnOutput, Stack
from aws_cdk.aws_opensearchserverless import (
    CfnSecurityPolicy,
    CfnAccessPolicy,
    CfnCollection
)
from constructs import Construct
from aws_cdk.aws_ssm import StringParameter

class OpenSearchVectorEngineStack(Stack):
    def __init__(
        self,
        scope: Construct,
        id: str,
        **kwargs
    ) -> None:

        super().__init__(scope, id, **kwargs)

        # opensearch variables
        collection_name = "movie"
        ecs_role_arn="arn:aws:iam::"+self.account+":role/GenAIServiceTaskRole"

        # network access
        self.network_policy = CfnSecurityPolicy(
            self,
            f'sample-vectordb-nw-{collection_name}',
            name=f'sample-vectordb-nw-{collection_name}',
            type='network',
            policy="""[{\"Rules\":[{\"ResourceType\":\"collection\",\"Resource\":[\"collection/"""+ collection_name + """\"]}, {\"ResourceType\":\"dashboard\",\"Resource\":[\"collection/"""+ collection_name + """\"]}],\"AllowFromPublic\":true}]"""
        )

        # encryption
        self.encryption_policy = CfnSecurityPolicy(
            self,
            f'sample-vectordb-encrypt-{collection_name}',
            name=f'sample-vectordb-encryption-{collection_name}',
            type='encryption',
            policy="""{\"Rules\":[{\"ResourceType\":\"collection\",\"Resource\":[\"collection/"""+ collection_name +"""\"]}],\"AWSOwnedKey\":true}"""
        )

        # data access
        self.data_access_policy = CfnAccessPolicy(
            self,
            f'sample-vectordb-data-{collection_name}',
            name=f'sample-vectordb-data-{collection_name}',
            type='data',
            policy="""[{\"Rules\":[{\"ResourceType\":\"index\",\"Resource\":[\"index/"""+ collection_name +"""/*\"], \"Permission\": [\"aoss:*\"]}, {\"ResourceType\":\"collection\",\"Resource\":[\"collection/"""+ collection_name +"""\"], \"Permission\": [\"aoss:*\"]}], \"Principal\": [\"""" + ecs_role_arn + """\"]}]"""
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
        self.cfn_collection.add_dependency(self.data_access_policy)

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
