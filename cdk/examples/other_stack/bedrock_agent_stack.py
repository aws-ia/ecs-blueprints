from aws_cdk import Duration, Stack
from aws_cdk.aws_iam import (
    ManagedPolicy, 
    Role, 
    ServicePrincipal, 
    PolicyStatement, 
    Effect
)
from aws_cdk.aws_ssm import StringParameter
import aws_cdk.aws_dynamodb as dynamodb
import aws_cdk.aws_lambda as lambda_
import aws_cdk.aws_lambda_python_alpha as lambda_python
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
            instruction= 'Use this knowledge base to answer questions about re:Invent 2024. It contains information of sessions.'
        )
        
        # create bedrock knowledge base data source
        self.knowledge_base_data_source = bedrock.S3DataSource(self, 'KnowledgeBaseDataSource',
            bucket= self.bucket,
            knowledge_base= self.knowledge_base,
            data_source_name= 'ReinventAgendaItem',
            chunking_strategy= bedrock.ChunkingStrategy.FIXED_SIZE,
            max_tokens=1000,
            overlap_percentage=20
        )
        
        # create bedrock agent 
        self.agent = bedrock.Agent(
            self,
            "BedrockAgent",
            name="bedrock-agent-for-reinvent",
            description="Amazon bedrock Agent for re:Invent 2024",
            foundation_model=bedrock.BedrockFoundationModel.ANTHROPIC_CLAUDE_HAIKU_V1_0,
            instruction="You are a helpful and friendly agent that answers questions about re:Invent 2024",
        )
        
        # integrate knowledge base to bedrock agent 
        self.agent.add_knowledge_base(self.knowledge_base)
        
        self.agent_alias = self.agent.add_alias(alias_name="bedrock-agent-for-reinvent")

        # create bedrock agent action group function
        action_group_lambda_role = Role(
            self,
            "LambdaExecutionRole",
            assumed_by=ServicePrincipal("lambda.amazonaws.com"),
            managed_policies=[
                ManagedPolicy.from_aws_managed_policy_name("service-role/AWSLambdaBasicExecutionRole")
            ]
        )

        action_group_lambda_role.add_to_policy(PolicyStatement(
            effect=Effect.ALLOW,
            actions=[
                "dynamodb:PutItem",
                "dynamodb:GetItem",
                "dynamodb:Scan"
            ],
            resources=[self.bookmark_table.table_arn]
        ))

        self.agent_action_group_function = lambda_python.PythonFunction(
            self,
            "BookmarkLambdaFunction",
            runtime=lambda_.Runtime.PYTHON_3_12,
            entry="lambda",
            index="index.py",
            handler="lambda_handler",
            timeout=Duration.seconds(300),
            role=action_group_lambda_role,
            environment={
                "TABLE_NAME": self.bookmark_table.table_name
            }
        )
        
        
        # create bedrock agent action group 
        self.actionGroup = bedrock.AgentActionGroup(self,
            "ReinventBookmarkActionGroup",
            action_group_name="reinvent-bookmark",
            description="Use these functions to get information about re:Invent 2024 sessions.",
            action_group_executor= bedrock.ActionGroupExecutor(
            lambda_=self.agent_action_group_function
            ),
            action_group_state="ENABLED",
            api_schema=bedrock.ApiSchema.from_asset("assets/action-group.yaml"))
        self.agent.add_action_group(self.actionGroup)
        
        # create parameter store
        self.agent_id_parameter = StringParameter(
            self, 
            "BedrockAgentIdParameter", 
            parameter_name="agent_id", 
            string_value=self.agent.agent_id
        )
        self.agent_alias_id_parameter = StringParameter(
            self, 
            "BedrockAgentAliasIdParameter", 
            parameter_name="agent_alias_id", 
            string_value=self.agent_alias.alias_id
        )        


