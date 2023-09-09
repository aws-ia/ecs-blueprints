from aws_cdk import PhysicalName, Stack
from aws_cdk.aws_ec2 import Vpc
from aws_cdk.aws_ecs import (
    CloudMapOptions,
    Cluster,
    ContainerImage,
    AwsLogDriver,
    Ec2TaskDefinition,
    NetworkMode,
    PortMapping,
    PidMode
)
from aws_cdk.aws_ecs_patterns import (
    ApplicationLoadBalancedEc2Service,
)
from aws_cdk.aws_iam import (
    ManagedPolicy,
    Effect,
    PolicyStatement,
    Role,
    ServicePrincipal
)
from aws_cdk.aws_logs import LogGroup, RetentionDays
from aws_cdk.aws_servicediscovery import PrivateDnsNamespace
from fis_service.lib.fis_service_stack_props import FISServiceStackProps

class FISServiceStack(Stack):
    def __init__(
        self,
        scope: Stack,
        id: str,
        fis_service_stack_prop: FISServiceStackProps,
        **kwargs
    ):
        super().__init__(scope, id, **kwargs)

        self.stack_props = fis_service_stack_prop
        self._ecs_cluster = None
        self._ecs_task_execution_role = None
        self._vpc = self.stack_props.vpc if self.stack_props.vpc else None
        self._sd_namespace = (
            self.stack_props.sd_namespace if self.stack_props.sd_namespace else None
        )

        self._create_ssm_managed_instance_role()
        self._create_ecs_task_role()

        log_group = LogGroup(
            self,
            "FISServiceLogGroup",
            retention=RetentionDays.ONE_WEEK,
            log_group_name=PhysicalName.GENERATE_IF_NEEDED,
        )

        ec2_task_image = Ec2TaskDefinition(
            self,
            "ECSEC2Task",
            execution_role=self.ecs_task_execution_role,
            task_role=self.ecs_task_role,
            pid_mode=PidMode.TASK,
            network_mode=NetworkMode.AWS_VPC
        )

        ec2_task_image.add_container(
            "app-container",
            container_name=self.stack_props.container_name,
            image=ContainerImage.from_registry(
                self.stack_props.container_image
            ),
            cpu=int(self.stack_props.task_cpu),
            memory_reservation_mib=int(self.stack_props.task_memory),
            port_mappings=[PortMapping(container_port=self.stack_props.container_port)],
            logging=AwsLogDriver(
                stream_prefix="ecs",
                log_group=log_group,
            ),
        )

        self.ec2_service = ApplicationLoadBalancedEc2Service(
            self,
            "FISEC2LBService",
            service_name=self.stack_props.service_name,
            cluster=self.ecs_cluster,
            desired_count=self.stack_props.desired_count,
            public_load_balancer=True,
            cloud_map_options=CloudMapOptions(
                cloud_map_namespace=self.sd_namespace,
                name=self.stack_props.service_name,
            ),
            task_definition=ec2_task_image,
            enable_ecs_managed_tags=True,

        )

        self.ec2_service.task_definition.add_container(
            "amazon-ssm-agent",
            image=ContainerImage.from_registry("public.ecr.aws/amazon-ssm-agent/amazon-ssm-agent:latest"),
            environment={
                "MANAGED_INSTANCE_ROLE_NAME": self.ssm_managed_instance_role.role_name
            },
            essential=False,
            memory_reservation_mib=64,
            command=[
                "/bin/bash",
                "-c",
                "set -e; yum upgrade -y; yum install jq procps awscli -y; term_handler() { echo \"Deleting SSM activation $ACTIVATION_ID\"; if ! aws ssm delete-activation --activation-id $ACTIVATION_ID --region $ECS_TASK_REGION; then echo \"SSM activation $ACTIVATION_ID failed to be deleted\" 1>&2; fi; MANAGED_INSTANCE_ID=$(jq -e -r .ManagedInstanceID /var/lib/amazon/ssm/registration); echo \"Deregistering SSM Managed Instance $MANAGED_INSTANCE_ID\"; if ! aws ssm deregister-managed-instance --instance-id $MANAGED_INSTANCE_ID --region $ECS_TASK_REGION; then echo \"SSM Managed Instance $MANAGED_INSTANCE_ID failed to be deregistered\" 1>&2; fi; kill -SIGTERM $SSM_AGENT_PID; }; trap term_handler SIGTERM SIGINT; if [[ -z $MANAGED_INSTANCE_ROLE_NAME ]]; then echo \"Environment variable MANAGED_INSTANCE_ROLE_NAME not set, exiting\" 1>&2; exit 1; fi; if ! ps ax | grep amazon-ssm-agent | grep -v grep > /dev/null; then if [[ -n $ECS_CONTAINER_METADATA_URI_V4 ]] ; then echo \"Found ECS Container Metadata, running activation with metadata\"; TASK_METADATA=$(curl \"${ECS_CONTAINER_METADATA_URI_V4}/task\"); ECS_TASK_AVAILABILITY_ZONE=$(echo $TASK_METADATA | jq -e -r '.AvailabilityZone'); ECS_TASK_ARN=$(echo $TASK_METADATA | jq -e -r '.TaskARN'); ECS_TASK_REGION=$(echo $ECS_TASK_AVAILABILITY_ZONE | sed 's/.$//'); ECS_TASK_AVAILABILITY_ZONE_REGEX='^(af|ap|ca|cn|eu|me|sa|us|us-gov)-(central|north|(north(east|west))|south|south(east|west)|east|west)-[0-9]{1}[a-z]{1}$'; if ! [[ $ECS_TASK_AVAILABILITY_ZONE =~ $ECS_TASK_AVAILABILITY_ZONE_REGEX ]]; then echo \"Error extracting Availability Zone from ECS Container Metadata, exiting\" 1>&2; exit 1; fi; ECS_TASK_ARN_REGEX='^arn:(aws|aws-cn|aws-us-gov):ecs:[a-z0-9-]+:[0-9]{12}:task/[a-zA-Z0-9_-]+/[a-zA-Z0-9]+$'; if ! [[ $ECS_TASK_ARN =~ $ECS_TASK_ARN_REGEX ]]; then echo \"Error extracting Task ARN from ECS Container Metadata, exiting\" 1>&2; exit 1; fi; CREATE_ACTIVATION_OUTPUT=$(aws ssm create-activation --iam-role $MANAGED_INSTANCE_ROLE_NAME --tags Key=ECS_TASK_AVAILABILITY_ZONE,Value=$ECS_TASK_AVAILABILITY_ZONE Key=ECS_TASK_ARN,Value=$ECS_TASK_ARN --region $ECS_TASK_REGION); ACTIVATION_CODE=$(echo $CREATE_ACTIVATION_OUTPUT | jq -e -r .ActivationCode); ACTIVATION_ID=$(echo $CREATE_ACTIVATION_OUTPUT | jq -e -r .ActivationId); if ! amazon-ssm-agent -register -code $ACTIVATION_CODE -id $ACTIVATION_ID -region $ECS_TASK_REGION; then echo \"Failed to register with AWS Systems Manager (SSM), exiting\" 1>&2; exit 1; fi; amazon-ssm-agent & SSM_AGENT_PID=$!; wait $SSM_AGENT_PID; else echo \"ECS Container Metadata not found, exiting\" 1>&2; exit 1; fi; else echo \"SSM agent is already running, exiting\" 1>&2; exit 1; fi"
            ]
        )

    @property
    def vpc(self):
        if not self._vpc:
            self._vpc = Vpc.from_lookup(
                self, "VpcLookup", vpc_name=self.stack_props.vpc_name
            )
        return self._vpc

    @property
    def sd_namespace(self):
        if not self._sd_namespace:
            self._sd_namespace = (
                PrivateDnsNamespace.from_private_dns_namespace_attributes(
                    self,
                    "SDNamespaceLookup",
                    namespace_name=self.stack_props.namespace_name,
                    namespace_arn=self.stack_props.namespace_arn,
                    namespace_id=self.stack_props.namespace_id,
                )
            )
        return self._sd_namespace

    @property
    def ecs_cluster(self):
        if not self._ecs_cluster:
            self._ecs_cluster = Cluster.from_cluster_attributes(
                self,
                "EcsClusterLookup",
                cluster_name=self.stack_props.ecs_cluster_name,
                security_groups=[],
                vpc=self.vpc,
                default_cloud_map_namespace=self.sd_namespace,
            )

        return self._ecs_cluster

    @property
    def ecs_task_execution_role(self) -> Role:
        if not self._ecs_task_execution_role:
            self._ecs_task_execution_role = Role.from_role_arn(
                self,
                "EcsTaskRoleFromArn",
                self.stack_props.ecs_task_execution_role_arn,
            )
        return self._ecs_task_execution_role

    def _create_ssm_managed_instance_role(self):
        self.ssm_managed_instance_role = Role(
            self,
            "SSMManagedInstanceRole",
            assumed_by=ServicePrincipal("ssm"),
            managed_policies=[
                ManagedPolicy.from_aws_managed_policy_name(
                    "AmazonSSMManagedInstanceCore"
                )
            ]
        )
        self.ssm_managed_instance_role.add_to_policy(
            PolicyStatement(
                effect=Effect.ALLOW,
                actions=[
                    "ssm:DeleteActivation",
                ],
                resources=["*"],
        ))
        self.ssm_managed_instance_role.add_to_policy(
            PolicyStatement(
                effect=Effect.ALLOW,
                actions=[
                    "ssm:DeregisterManagedInstance",
                ],
                resources=['arn:aws:ssm:'+self.stack_props.aws_region+':'+self.stack_props.account_number+':managed-instance/*'],
        ))

    def _create_ecs_task_role(self):
        self.ecs_task_role = Role(
            self,
            "ECSTaskRole",
            assumed_by=ServicePrincipal("ecs-tasks"),
        )
        self.ecs_task_role.add_to_policy(PolicyStatement(
            effect=Effect.ALLOW,
            actions=[
                "iam:PassRole",
            ],
            resources=['arn:aws:iam::'+self.stack_props.account_number+':role/'+self.ssm_managed_instance_role.role_name],
        ))
        self.ecs_task_role.add_to_policy(PolicyStatement(
            effect=Effect.ALLOW,
            actions=[
                "ssm:CreateActivation",
                "ssm:AddTagsToResource",
            ],
            resources=["*"],
        ))


    def validate_stack_props(self):
        if (
            self.stack_props.account_number == "<ACCOUNT_NUMBER>"
            or self.stack_props.aws_region == "<REGION>"
        ):
            raise ValueError(
                "Environment values needs to be set for account_number, aws_region"
            )
