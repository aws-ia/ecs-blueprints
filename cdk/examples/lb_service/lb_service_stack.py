from aws_cdk import RemovalPolicy, SecretValue, Stack, StackProps
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
from aws_cdk.aws_ecs import CloudMapOptions, Cluster, ContainerImage, LogDriver
from aws_cdk.aws_ecs_patterns import (
    ApplicationLoadBalancedFargateService,
    ApplicationLoadBalancedTaskImageOptions,
)
from aws_cdk.aws_iam import (
    AnyPrincipal,
    Effect,
    PolicyStatement,
    Role,
    ServicePrincipal,
)
from aws_cdk.aws_logs import LogGroup, RetentionDays
from aws_cdk.aws_s3 import BlockPublicAccess, Bucket, BucketEncryption
from aws_cdk.aws_servicediscovery import PrivateDnsNamespace


class LoadBalancedServiceStackProps(StackProps):
    def __init__(
        self,
        namespace_name=None,
        namespace_arn=None,
        namespace_id=None,
        ecs_cluster_name=None,
        ecs_task_execution_role_arn=None,
        container_name=None,
        container_port=None,
        folder_path=None,
        backend_svc_endpoint=None,
        repository_owner=None,
        repository_name=None,
        repository_branch=None,
        buildspec_path=None,
        service_name=None,
        task_cpu=None,
        task_memory=None,
        desired_count=None,
        github_token_secret_name=None,
        aws_region=None,
    ):
        self.namespace_name = namespace_name
        self.namespace_arn = namespace_arn
        self.namespace_id = namespace_id
        self.ecs_cluster_name = ecs_cluster_name
        self.ecs_task_execution_role_arn = ecs_task_execution_role_arn
        self.container_name = container_name
        self.container_port = container_port
        self.folder_path = folder_path
        self.backend_svc_endpoint = backend_svc_endpoint
        self.repository_owner = repository_owner
        self.repository_name = repository_name
        self.repository_branch = repository_branch
        self.buildspec_path = buildspec_path
        self.service_name = service_name
        self.task_cpu = task_cpu
        self.task_memory = task_memory
        self.desired_count = desired_count
        self.github_token_secret_name = github_token_secret_name
        self.aws_region = aws_region


class LoadBalancedServiceStack(Stack):
    def __init__(
        self,
        scope: Stack,
        id: str,
        lb_service_stack_prop: LoadBalancedServiceStackProps,
        core_infra_stack: Stack,
        **kwargs
    ):
        super().__init__(scope, id, **kwargs)

        self.stack_props = lb_service_stack_prop
        self.core_infra_stack = core_infra_stack
        self.ecs_task_execution_role = Role.from_role_arn(
            self, "EcsTaskRoleFromArn", self.stack_props.ecs_task_execution_role_arn
        )
        self._create_codebuild_role()
        self._create_ecr_repository()
        self._create_codebuild_project()
        self._create_artifacts()
        self._create_ecs_code_pipeline_role()
        self._create_ecs_service()
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

    def _create_artifacts(self):
        self.source_artifact = Artifact("SourceArtifact")
        self.build_artifact = Artifact("BuildArtifact")

        self.artifacts_bucket = Bucket(
            self,
            "ArtifactsBucket",
            encryption=BucketEncryption.S3_MANAGED,
            block_public_access=BlockPublicAccess.BLOCK_ALL,
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

    def _create_codebuild_project(self):
        environment = BuildEnvironment(
            build_image=LinuxBuildImage.STANDARD_5_0,
            compute_type=ComputeType.SMALL,
            privileged=True,
            environment_variables={
                "REPO_URL": BuildEnvironmentVariable(
                    value=self.ecr_repository.repository_uri
                ),
                "CONTAINER_NAME": BuildEnvironmentVariable(
                    value=self.stack_props.container_name
                ),
                "SERVICE_PORT": BuildEnvironmentVariable(
                    value=self.stack_props.container_port
                ),
                "FOLDER_PATH": BuildEnvironmentVariable(
                    value=self.stack_props.folder_path
                ),
                "ECS_EXEC_ROLE_ARN": BuildEnvironmentVariable(
                    value=self.codebuild_role.role_arn
                ),
                "BACKEND_SVC_ENDPOINT": BuildEnvironmentVariable(
                    value=self.stack_props.backend_svc_endpoint
                ),
            },
        )
        self.git_hub_repo = Source.git_hub(
            owner=self.stack_props.repository_owner,
            repo=self.stack_props.repository_name,
            branch_or_ref=self.stack_props.repository_branch,
        )
        self.codebuild_project = Project(
            self,
            "CodeBuild",
            role=self.codebuild_role,
            description="Code build project for the application",
            environment=environment,
            source=self.git_hub_repo,
            build_spec=BuildSpec.from_source_filename(self.stack_props.buildspec_path),
        )

    def _create_ecr_repository(self):
        self.ecr_repository = Repository(
            self,
            "EcrRepository",
            repository_name=self.stack_props.container_name,
            removal_policy=RemovalPolicy.DESTROY,
        )

        self.ecr_repository.grant_pull(self.ecs_task_execution_role)
        self.ecr_repository.grant_pull_push(self.codebuild_role)

    def _create_ecs_service(self):
        log_group = LogGroup(
            self,
            "LBServiceLogGroup",
            retention=RetentionDays.ONE_WEEK,
        )

        fargate_task_image = ApplicationLoadBalancedTaskImageOptions(
            container_name=self.stack_props.container_name,
            image=ContainerImage.from_registry(
                "public.ecr.aws/aws-containers/ecsdemo-frontend"
            ),
            container_port=self.stack_props.container_port,
            execution_role=self.ecs_task_execution_role,
            log_driver=LogDriver.aws_logs(
                stream_prefix="ecs",
                log_group=log_group,
            ),
            environment={
                "NODEJS_URL": self.stack_props.backend_svc_endpoint,
            },
        )

        self.sd_namespace = PrivateDnsNamespace.from_private_dns_namespace_attributes(
            self,
            "SDNamespace",
            namespace_name=self.stack_props.namespace_name,
            namespace_arn=self.stack_props.namespace_arn,
            namespace_id=self.stack_props.namespace_id,
        )
        self.fargate_service = ApplicationLoadBalancedFargateService(
            self,
            "FrontendFargateLBService",
            service_name=self.stack_props.service_name,
            cluster=Cluster.from_cluster_attributes(
                self,
                "EcsClusterFromArn",
                cluster_arn=self.core_infra_stack.cluster.cluster_arn,
                vpc=self.core_infra_stack.vpc,
                security_groups=[],
                cluster_name=self.core_infra_stack.cluster.cluster_name,
            ),
            cpu=int(self.stack_props.task_cpu),
            memory_limit_mib=int(self.stack_props.task_memory),
            desired_count=self.stack_props.desired_count,
            enable_execute_command=True,
            public_load_balancer=True,
            cloud_map_options=CloudMapOptions(
                cloud_map_namespace=self.sd_namespace,
                name="ecsdemo-frontend",
            ),
            task_image_options=fargate_task_image,
        ).service

        scalable_target = self.fargate_service.auto_scale_task_count(
            min_capacity=3, max_capacity=10
        )

        scalable_target.scale_on_cpu_utilization(
            "CpuScaling", target_utilization_percent=50
        )

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
                            owner=self.stack_props.repository_owner,
                            repo=self.stack_props.repository_name,
                            branch=self.stack_props.repository_branch,
                            oauth_token=SecretValue.secrets_manager(
                                self.stack_props.github_token_secret_name
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
                            service=self.fargate_service,
                            image_file=self.build_artifact.at_path(
                                "imagedefinition.json"
                            ),
                        )
                    ],
                ),
            ],
        )