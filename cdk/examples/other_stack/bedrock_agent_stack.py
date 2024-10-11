from aws_cdk import Stack, RemovalPolicy
from aws_cdk.aws_ssm import StringParameter
import aws_cdk.aws_dynamodb as dynamodb
import aws_cdk.aws_s3 as s3
import os
import aws_cdk.aws_s3_deployment as s3_deployment
from cdklabs.generative_ai_cdk_constructs import (
    bedrock
)

from constructs import Construct

class BedrockAgentStack(Stack):
    def __init__(
        self,
        scope: Construct,
        id: str,
        **kwargs
    ) -> None:

        super().__init__(scope, id, **kwargs)

        # create dynamodb table
        self.bookmark_table = dynamodb.Table(
            self,
            "ReinventBookmarkTable",
            table_name="reinvent-bookmark",
            partition_key=dynamodb.Attribute(name="sessionCode",
                                             type=dynamodb.AttributeType.STRING),
            billing_mode=dynamodb.BillingMode.PAY_PER_REQUEST,
            removal_policy=RemovalPolicy.DESTROY,
        )

        # create S3 bucket
        self.bucket = s3.Bucket(
            self,
            "RAGBucket"
        )

        # upload riv 2024 information
        s3_deployment.BucketDeployment(
            self,
            "ReinventAgendaItem",
            destination_bucket=self.bucket,
            sources=[s3_deployment.Source.asset(os.path.join("assets"))]
        )

        # create bedrock knowledge base
        self.knowledge_base = bedrock.KnowledgeBase(self, 'KnowledgeBase',
            name="bedrock-knowledge-base-for-reinvent",
            description="Amazon Bedrock Knowledge Base for re:Invent 2024",
            embeddings_model= bedrock.BedrockFoundationModel.TITAN_EMBED_TEXT_V2_1024,
            instruction= 'Use this knowledge base to answer questions about re:Invent 2024 session information. It contains title, session code, sponsor, description, session type, topic, areas of interest, level, target roles, venue, date and time, prerequisites, key points, and related AWS services.'
        )

        # create bedrock knowledge base data source
        self.knowledge_base_data_source = bedrock.S3DataSource(self, 'KnowledgeBaseDataSource',
            bucket=self.bucket,
            knowledge_base=self.knowledge_base,
            data_source_name='ReinventSessionInformationText',
            chunking_strategy= bedrock.ChunkingStrategy.fixed_size(
                max_tokens= 512,
                overlap_percentage= 20
            )
        )

        # create parameter store
        self.agent_id_parameter = StringParameter(
            self,
            "BedrockKnowledgeBaseIdParameter",
            parameter_name="knowledge_base_id",
            string_value=self.knowledge_base.knowledge_base_id
        )