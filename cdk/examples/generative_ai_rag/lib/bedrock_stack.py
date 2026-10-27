from aws_cdk import Stack
from aws_cdk.aws_opensearchserverless import CfnSecurityPolicy
from aws_cdk.aws_ssm import StringParameter
import aws_cdk.aws_s3 as s3
import os
import aws_cdk.aws_s3_deployment as s3_deployment
from cdklabs.generative_ai_cdk_constructs import (
    bedrock,
    opensearchserverless,
)

from constructs import Construct


def create_private_vector_collection(
    scope: Construct,
) -> opensearchserverless.VectorCollection:
    collection = opensearchserverless.VectorCollection(
        scope,
        "KnowledgeBaseVectorStore",
    )
    network_policy = collection.node.find_child("NetworkPolicy")
    if not isinstance(network_policy, CfnSecurityPolicy):
        raise TypeError("Vector collection network policy was not created")

    # The construct's index-creation custom resource runs in a Lambda function with
    # no VPC attachment, so the collection endpoint must stay reachable from public
    # networks or index creation fails at deploy time. IAM data-access policies still
    # authorize every request. This policy removes the construct's default public
    # dashboard rule; move to SourceVPCEs with a VPC-attached custom resource to
    # remove the public data path entirely.
    network_policy.policy = Stack.of(scope).to_json_string(
        [
            {
                "Rules": [
                    {
                        "ResourceType": "collection",
                        "Resource": [f"collection/{collection.collection_name}"],
                    }
                ],
                "AllowFromPublic": True,
            }
        ]
    )
    return collection


class BedrockStack(Stack):
    def __init__(
        self,
        scope: Construct,
        id: str,
        **kwargs
    ) -> None:

        super().__init__(scope, id, **kwargs)

        # create S3 bucket
        self.bucket = s3.Bucket(
            self,
            "RAGBucket",
            block_public_access=s3.BlockPublicAccess.BLOCK_ALL,
            enforce_ssl=True,
        )

        # upload riv 2024 information
        s3_deployment.BucketDeployment(
            self,
            "ReinventAgendaItem",
            destination_bucket=self.bucket,
            sources=[s3_deployment.Source.asset(os.path.join("assets"))]
        )

        self.vector_store = create_private_vector_collection(self)

        # create bedrock knowledge base
        self.knowledge_base = bedrock.VectorKnowledgeBase(self, 'KnowledgeBase',
            name="bedrock-knowledge-base-for-reinvent",
            description="Amazon Bedrock Knowledge Base for re:Invent 2024",
            embeddings_model= bedrock.BedrockFoundationModel.TITAN_EMBED_TEXT_V2_1024,
            vector_store=self.vector_store,
            instruction= 'Use this knowledge base to answer questions about re:Invent 2024 session information. It contains title, session code, sponsor, description, session type, topic, areas of interest, level, target roles, venue, date and time, prerequisites, key points, and related AWS services.'
        )

        # create bedrock knowledge base data source
        self.knowledge_base_data_source = bedrock.S3DataSource(self, 'KnowledgeBaseDataSource',
            bucket=self.bucket,
            knowledge_base=self.knowledge_base,
            data_source_name='ReinventSessionInformationText',
            chunking_strategy= bedrock.ChunkingStrategy.hierarchical(
                overlap_tokens=60,
                max_parent_token_size=1500,
                max_child_token_size=300
            )
        )

        # create parameter store
        self.kb_id_parameter = StringParameter(
            self,
            "BedrockKnowledgeBaseIdParameter",
            parameter_name="knowledge_base_id",
            string_value=self.knowledge_base.knowledge_base_id
        )
