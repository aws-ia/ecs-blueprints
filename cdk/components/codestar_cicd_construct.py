from aws_cdk import RemovalPolicy, SecretValue, StackProps
from aws_cdk.aws_codebuild import (
    BuildEnvironment,
    BuildEnvironmentVariable,
    BuildSpec,
    ComputeType,
    LinuxBuildImage,
    Project,
    Source,
)
from aws_cdk.aws_codepipeline import Artifact, Pipeline, StageProps
from aws_cdk.aws_codepipeline_actions import (
    CodeBuildAction,
    EcsDeployAction,
    GitHubSourceAction,
)
from aws_cdk.aws_ecr import Repository
from aws_cdk.aws_iam import (
    AnyPrincipal,
    Effect,
    PolicyStatement,
    Role,
    ServicePrincipal,
)
from aws_cdk.aws_s3 import BlockPublicAccess, Bucket, BucketEncryption
from constructs import Construct


class CICDConstructProps(StackProps):
    def __init__(
        self,
        backend_svc_endpoint=None,
        buildspec_path=None,
        container_name=None,
        container_port=None,
        ecr_repository_name=None,
        ecs_task_execution_role=None,
        fargate_service=None,
        folder_path=None,
        github_token_secret_name=None,
        repository_owner=None,
        repository_name=None,
        repository_branch=None,
    ) -> None:
        self.buildspec_path = buildspec_path
        self.backend_svc_endpoint = backend_svc_endpoint
        self.container_name = container_name
        self.container_port = int(container_port)
        self.ecr_repository_name = ecr_repository_name
        self.ecs_task_execution_role = ecs_task_execution_role
        self.fargate_service = fargate_service
        self.folder_path = folder_path
        self.github_token_secret_name = github_token_secret_name
        self.repository_owner = repository_owner
        self.repository_name = repository_name
        self.repository_branch = repository_branch


class CodeStarCICDConstruct(Construct):
    def __init__(
        self,
        scope: Construct,
        id: str,
        cicd_props: CICDConstructProps,
        **kwargs,
    ) -> None:
        super().__init__(scope, id, **kwargs)

        self.cicd_props = cicd_props

        self._create_codebuild_role()
        self._create_ecr_repository()
        self._create_codebuild_project()
        self._create_artifacts()
        self._create_ecs_code_pipeline_role()
        self._create_codepipeline_pipeline()

    def _create_codebuild_role(self):
        self.codebuild_role = Role(
            self,
            "codeBuildServiceRole",
            assumed_by=ServicePrincipal("codebuild.amazonaws.com"),
        )

        inline_policy = PolicyStatement(
            effect=Effect.ALLOW,
            actions=[
                "ecr:GetAuthorizationToken",
                "ecr:BatchCheckLayerAvailability",
                "ecr:InitiateLayerUpload",
                "ecr:UploadLayerPart",
                "ecr:CompleteLayerUpload",
                "ecr:PutImage",
                "s3:Get*",
                "s3:List*",
                "s3:PutObject",
                "secretsmanager:GetSecretValue",
            ],
            resources=["*"],
        )

        self.codebuild_role.add_to_policy(inline_policy)

    def _create_ecr_repository(self):
        self.ecr_repository = Repository(
            self,
            "EcrRepository",
            repository_name=self.cicd_props.ecr_repository_name,
            removal_policy=RemovalPolicy.DESTROY,
        )

        self.ecr_repository.grant_pull(self.cicd_props.ecs_task_execution_role)
        self.ecr_repository.grant_pull_push(self.codebuild_role)

    def _create_codebuild_project(self):

        build_environment_variables = {
            "REPO_URL": BuildEnvironmentVariable(
                value=self.ecr_repository.repository_uri
            ),
            "CONTAINER_NAME": BuildEnvironmentVariable(
                value=self.cicd_props.container_name
            ),
            "SERVICE_PORT": BuildEnvironmentVariable(
                value=self.cicd_props.container_port
            ),
            "FOLDER_PATH": BuildEnvironmentVariable(
                value=self.cicd_props.folder_path
            ),
            "ECS_EXEC_ROLE_ARN": BuildEnvironmentVariable(
                value=self.codebuild_role.role_arn
            ),
        }

        if self.cicd_props.backend_svc_endpoint:
            build_environment_variables["BACKEND_SVC_ENDPOINT"] =  BuildEnvironmentVariable(
                value=self.cicd_props.backend_svc_endpoint
            )

        environment = BuildEnvironment(
            build_image=LinuxBuildImage.STANDARD_5_0,
            compute_type=ComputeType.SMALL,
            privileged=True,
            environment_variables=build_environment_variables
        )

        self.git_hub_repo = Source.git_hub(
            owner=self.cicd_props.repository_owner,
            repo=self.cicd_props.repository_name,
            branch_or_ref=self.cicd_props.repository_branch,
        )
        self.codebuild_project = Project(
            self,
            "CodeBuildProject",
            role=self.codebuild_role,
            description="Code build project for the application",
            environment=environment,
            source=self.git_hub_repo,
            build_spec=BuildSpec.from_source_filename(self.cicd_props.buildspec_path),
        )

    def _create_artifacts(self):
        self.source_artifact = Artifact("SourceArtifact")
        self.build_artifact = Artifact("BuildArtifact")

        self.artifacts_bucket = Bucket(
            self,
            "ArtifactsBucket",
            encryption=BucketEncryption.S3_MANAGED,
            block_public_access=BlockPublicAccess.BLOCK_ALL,
            removal_policy=RemovalPolicy.DESTROY,
            auto_delete_objects=True
        )

        deny_unencrypted_object_uploads = PolicyStatement(
            effect=Effect.DENY,
            actions=["s3:PutObject"],
            principals=[AnyPrincipal()],
            resources=[self.artifacts_bucket.bucket_arn + "/*"],
            conditions={
                "StringNotEquals": {"s3:x-amz-server-side-encryption": "aws:kms"}
            },
        )

        deny_insecure_connections = PolicyStatement(
            effect=Effect.DENY,
            actions=["s3:*"],
            principals=[AnyPrincipal()],
            resources=[self.artifacts_bucket.bucket_arn + "/*"],
            conditions={"Bool": {"aws:SecureTransport": "false"}},
        )

        self.artifacts_bucket.add_to_resource_policy(deny_unencrypted_object_uploads)
        self.artifacts_bucket.add_to_resource_policy(deny_insecure_connections)

    def _create_ecs_code_pipeline_role(self):
        self.code_pipeline_role = Role(
            self,
            "CodePipelineRole",
            assumed_by=ServicePrincipal("codepipeline.amazonaws.com"),
        )

        inline_policy = PolicyStatement(
            effect=Effect.ALLOW,
            actions=[
                "iam:PassRole",
                "sts:AssumeRole",
                "codecommit:Get*",
                "codecommit:List*",
                "codecommit:GitPull",
                "codecommit:UploadArchive",
                "codecommit:CancelUploadArchive",
                "codebuild:BatchGetBuilds",
                "codebuild:StartBuild",
                "codedeploy:CreateDeployment",
                "codedeploy:Get*",
                "codedeploy:RegisterApplicationRevision",
                "s3:Get*",
                "s3:List*",
                "s3:PutObject",
            ],
            resources=["*"],
        )

        self.code_pipeline_role.add_to_policy(inline_policy)

    def _create_codepipeline_pipeline(self):
        self.pipeline = Pipeline(
            self,
            "EcsRollingDeployment",
            role=self.code_pipeline_role,
            artifact_bucket=self.artifacts_bucket,
            stages=[
                StageProps(
                    stage_name="Source",
                    actions=[
                        GitHubSourceAction(
                            action_name="source",
                            owner=self.cicd_props.repository_owner,
                            repo=self.cicd_props.repository_name,
                            branch=self.cicd_props.repository_branch,
                            oauth_token=SecretValue.secrets_manager(
                                self.cicd_props.github_token_secret_name
                            ),
                            output=self.source_artifact,
                        )
                    ],
                ),
                StageProps(
                    stage_name="Build",
                    actions=[
                        CodeBuildAction(
                            action_name="Build",
                            project=self.codebuild_project,
                            input=self.source_artifact,
                            outputs=[self.build_artifact],
                        )
                    ],
                ),
                StageProps(
                    stage_name="Deploy",
                    actions=[
                        EcsDeployAction(
                            action_name="Deploy",
                            service=self.cicd_props.fargate_service,
                            image_file=self.build_artifact.at_path(
                                "imagedefinitions.json"
                            ),
                        )
                    ],
                ),
            ],
        )
