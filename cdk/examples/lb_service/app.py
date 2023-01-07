#!/usr/bin/env python3
import os

import aws_cdk as cdk
from aws_cdk import (
    Stack,
    SecretValue,
    RemovalPolicy,
    aws_s3 as s3,
    aws_codebuild as codebuild,
    aws_codepipeline as codepipeline,
    aws_codepipeline_actions as codepipeline_actions,
    aws_ecr as ecr,
    aws_ecs as ecs,
    aws_ecs_patterns as ecs_patterns,
    aws_ec2 as ec2,
    aws_iam as iam,
    aws_logs as logs,
    aws_servicediscovery as servicediscovery,
)
from constructs import Construct


class BaseInfrastructure(Construct):
    def __init__(self, scope: Construct, id: str, **kwargs):
        super().__init__(scope, id, **kwargs)

        self.vpc = ec2.Vpc.from_lookup(
            self, "VPC", vpc_id=self.node.try_get_context("vpc_id")
        )

        self.sd_namespace = servicediscovery.PrivateDnsNamespace.from_private_dns_namespace_attributes(
            self,
            "SDNamespace",
            namespace_name=self.node.try_get_context("namespace_name"),
            namespace_arn=self.node.try_get_context("namespace_arn"),
            namespace_id=self.node.try_get_context("namespace_id"),
        )

        self.ecs_cluster = ecs.Cluster.from_cluster_attributes(
            self,
            "ECSCluster",
            cluster_name=self.node.try_get_context("ecs_cluster_name"),
            security_groups=[],
            vpc=self.vpc,
            default_cloud_map_namespace=self.sd_namespace,
        )

        self.task_execution_role = iam.Role.from_role_arn(
            self,
            "TaskExecutionRole",
            self.node.try_get_context("ecs_task_execution_role_arn"),
        )


class LoadBalancedServiceStack(Stack):
    def _create_codebuild_role(self):
        self.codebuild_role = iam.Role(
            self,
            "codeBuildServiceRole",
            assumed_by=iam.ServicePrincipal("codebuild.amazonaws.com"),
        )

        inline_policy = iam.PolicyStatement(
            effect=iam.Effect.ALLOW,
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
        self.code_pipeline_role = iam.Role(
            self,
            "CodePipelineRole",
            assumed_by=iam.ServicePrincipal("codepipeline.amazonaws.com"),
        )

        inline_policy = iam.PolicyStatement(
            effect=iam.Effect.ALLOW,
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
        self.source_artifact = codepipeline.Artifact("sourceArtifact")
        self.build_artifact = codepipeline.Artifact("buildArtifact")

        self.artifacts_bucket = s3.Bucket(
            self,
            "artifactsBucket",
            encryption=s3.BucketEncryption.S3_MANAGED,
            block_public_access=s3.BlockPublicAccess.BLOCK_ALL,
        )

        deny_unencrypted_object_uploads = iam.PolicyStatement(
            effect=iam.Effect.DENY,
            actions=["s3:PutObject"],
            principals=[iam.AnyPrincipal()],
            resources=[self.artifacts_bucket.bucket_arn + "/*"],
            conditions={
                "StringNotEquals": {
                    "s3:x-amz-server-side-encryption": "aws:kms"
                }
            },
        )

        deny_insecure_connections = iam.PolicyStatement(
            effect=iam.Effect.DENY,
            actions=["s3:*"],
            principals=[iam.AnyPrincipal()],
            resources=[self.artifacts_bucket.bucket_arn + "/*"],
            conditions={"Bool": {"aws:SecureTransport": "false"}},
        )

        self.artifacts_bucket.add_to_resource_policy(
            deny_unencrypted_object_uploads
        )
        self.artifacts_bucket.add_to_resource_policy(deny_insecure_connections)

    def _create_codebuild_project(self):
        environment = codebuild.BuildEnvironment(
            build_image=codebuild.LinuxBuildImage.STANDARD_5_0,
            compute_type=codebuild.ComputeType.SMALL,
            privileged=True,
            environment_variables={
                "REPO_URL": codebuild.BuildEnvironmentVariable(
                    value=self.ecr_repository.repository_uri
                ),
                "CONTAINER_NAME": codebuild.BuildEnvironmentVariable(
                    value=self.node.try_get_context("container_name")
                ),
                "SERVICE_PORT": codebuild.BuildEnvironmentVariable(
                    value=self.node.try_get_context("container_port")
                ),
                "FOLDER_PATH": codebuild.BuildEnvironmentVariable(
                    value=self.node.try_get_context("folder_path")
                ),
                "ECS_EXEC_ROLE_ARN": codebuild.BuildEnvironmentVariable(
                    value=self.codebuild_role.role_arn
                ),
                "BACKEND_SVC_ENDPOINT": codebuild.BuildEnvironmentVariable(
                    value= self.node.try_get_context("backend_svc_endpoint")
                )
            },
        )
        self.git_hub_repo = codebuild.Source.git_hub(
            owner=self.node.try_get_context("repository_owner"),
            repo=self.node.try_get_context("repository_name"),
            branch_or_ref=self.node.try_get_context("repository_branch"),
        )
        self.codebuild_project = codebuild.Project(
            self,
            "codeBuild",
            role=self.codebuild_role,
            description="Code build project for the application",
            environment=environment,
            source=self.git_hub_repo,
            build_spec=codebuild.BuildSpec.from_source_filename(
                self.node.try_get_context("buildspec_path")
            )
        )

    def _create_ecr_repository(self):

        self.ecr_repository = ecr.Repository(
            self,
            "ecr-repository",
            repository_name=self.node.try_get_context("container_name"),
            removal_policy=RemovalPolicy.DESTROY,
        )

        self.ecr_repository.grant_pull(self.base_platform.task_execution_role)
        self.ecr_repository.grant_pull_push(self.codebuild_role)

    def _create_ecs_service(self):

        log_group = logs.LogGroup(
            self,
            "log-group",
            retention=logs.RetentionDays.ONE_WEEK,
        )

        fargate_task_image = ecs_patterns.ApplicationLoadBalancedTaskImageOptions(
            container_name=self.node.try_get_context("container_name"),
            image=ecs.ContainerImage.from_registry("public.ecr.aws/aws-containers/ecsdemo-frontend"),
            container_port=self.node.try_get_context("container_port"),
            execution_role=self.base_platform.task_execution_role,
            log_driver=ecs.LogDriver.aws_logs(
                stream_prefix="ecs",
                log_group=log_group,
            ),
            environment={
                "NODEJS_URL": self.node.try_get_context("backend_svc_endpoint"),
            },
        )

        self.fargate_service = ecs_patterns.ApplicationLoadBalancedFargateService(
            self,
            "FrontendFargateLBService",
            service_name=self.node.try_get_context("service_name"),
            cluster=self.base_platform.ecs_cluster,
            cpu=int(self.node.try_get_context("task_cpu")),
            memory_limit_mib=int(self.node.try_get_context("task_memory")),
            desired_count=self.node.try_get_context("desired_count"),
            enable_execute_command=True,
            public_load_balancer=True,
            cloud_map_options=ecs.CloudMapOptions(
                cloud_map_namespace=self.base_platform.sd_namespace,
                name="ecsdemo-frontend",
            ),            
            task_image_options=fargate_task_image
        ).service

        scalable_target = (
            self.fargate_service.auto_scale_task_count(
                min_capacity=3, max_capacity=10
            )
        )

        scalable_target.scale_on_cpu_utilization(
            "CpuScaling", target_utilization_percent=50
        )

    def _create_codepipeline_pipeline(self):

        self.pipeline = codepipeline.Pipeline(
            self,
            "ecs-rolling-deployment",
            role=self.code_pipeline_role,
            artifact_bucket=self.artifacts_bucket,
            stages=[
                codepipeline.StageProps(
                    stage_name="Source",
                    actions=[
                        codepipeline_actions.GitHubSourceAction(
                            action_name="source",
                            owner=self.node.try_get_context("repository_owner"),
                            repo=self.node.try_get_context("repository_name"),
                            branch=self.node.try_get_context("repository_branch"),
                            oauth_token=SecretValue.secrets_manager(
                                self.node.try_get_context(
                                    "github_token_secret_name"
                                )
                            ),
                            output=self.source_artifact,
                        )
                    ],
                ),
                codepipeline.StageProps(
                    stage_name="Build",
                    actions=[
                        codepipeline_actions.CodeBuildAction(
                            action_name="Build",
                            project=self.codebuild_project,
                            input=self.source_artifact,
                            outputs=[self.build_artifact],
                        )
                    ],
                ),
                codepipeline.StageProps(
                    stage_name="Deploy",
                    actions=[
                        codepipeline_actions.EcsDeployAction(
                            action_name="Deploy",
                            service=self.fargate_service,
                            image_file=self.build_artifact.at_path(
                                "imagedefinition.json"
                            )
                        )
                    ],
                ),
            ],
        )

    def __init__(self, scope: Stack, id: str, **kwargs):
        super().__init__(scope, id, **kwargs)

        self.base_platform = BaseInfrastructure(self, self.stack_name)

        self._create_codebuild_role()
        self._create_ecr_repository()
        self._create_codebuild_project()
        self._create_artifacts()
        self._create_ecs_code_pipeline_role()
        self._create_ecs_service()
        self._create_codepipeline_pipeline()


app = cdk.App()

LoadBalancedServiceStack(
    app,
    "frontend-service",
    env=cdk.Environment(
        account=os.getenv("CDK_DEFAULT_ACCOUNT"),
        region=app.node.try_get_context("aws_region"),
    ),
)

app.synth()