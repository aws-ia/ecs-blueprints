import os
import aws_cdk.aws_iam as iam
from lib.data_pipeline_stack_props import DataPipelineStackProps

def add_step_function_role_policies(stepfunctionExecutionRole:iam.Role, data_pipeline_stack_props: DataPipelineStackProps):
    stepfunctionExecutionRole.add_to_principal_policy(iam.PolicyStatement(
        actions= ['ecs:RunTask'],
        effect= iam.Effect.ALLOW,
        resources= ['arn:aws:ecs:'+data_pipeline_stack_props.aws_region+':'+data_pipeline_stack_props.account_number+':task-definition/*']
    ))
    stepfunctionExecutionRole.add_to_principal_policy(iam.PolicyStatement(
        actions= ["logs:CreateLogDelivery",
        "logs:GetLogDelivery",
        "logs:UpdateLogDelivery",
        "logs:DeleteLogDelivery",
        "logs:ListLogDeliveries",
        "logs:PutResourcePolicy",
        "logs:DescribeResourcePolicies",
        "logs:DescribeLogGroups"],
        effect= iam.Effect.ALLOW,
        resources= ["*"]
    ))
    stepfunctionExecutionRole.add_to_principal_policy(iam.PolicyStatement(
        actions= ["xray:PutTraceSegments",
        "xray:PutTelemetryRecords",
        "xray:GetSamplingRules",
        "xray:GetSamplingTargets"],
        effect= iam.Effect.ALLOW,
        resources= ["*"]
    ))

    return stepfunctionExecutionRole

def add_ecs_task_execution_role_policies(ecsTaskExecutionRole:iam.Role, data_pipeline_stack_props: DataPipelineStackProps):
    ecsTaskExecutionRole.add_to_principal_policy(iam.PolicyStatement(
        actions= ["ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"],
        effect= iam.Effect.ALLOW,
        resources= ['arn:aws:ecr:'+data_pipeline_stack_props.aws_region+':'+data_pipeline_stack_props.account_number+':*']
    ))
    ecsTaskExecutionRole.add_to_principal_policy(iam.PolicyStatement(
        actions= ["logs:CreateLogStream",
        "logs:PutLogEvents"],
        effect= iam.Effect.ALLOW,
        resources= ["*"]
    ))
    ecsTaskExecutionRole.add_to_principal_policy(iam.PolicyStatement(
        actions= ["ec2:AuthorizeSecurityGroupIngress",
        "ec2:Describe*"],
        effect= iam.Effect.ALLOW,
        resources= ['arn:aws:ec2:'+data_pipeline_stack_props.aws_region+':'+data_pipeline_stack_props.account_number+':*']
    ))
    ecsTaskExecutionRole.add_to_principal_policy(iam.PolicyStatement(
        actions= ["elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
        "elasticloadbalancing:DeregisterTargets",
        "elasticloadbalancing:Describe*",
        "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
        "elasticloadbalancing:RegisterTargets"],
        effect= iam.Effect.ALLOW,
        resources= ['arn:aws:elasticloadbalancing:'+data_pipeline_stack_props.aws_region+':'+data_pipeline_stack_props.account_number+':*']
    ))

    return ecsTaskExecutionRole

def add_ecs_task_role_policies(ecsTaskRole: iam.Role, data_pipeline_stack_props: DataPipelineStackProps):
    ecsTaskRole.add_to_principal_policy(iam.PolicyStatement(
        actions= ["states:*"],
        effect= iam.Effect.ALLOW,
        resources= ['arn:aws:states:'+data_pipeline_stack_props.aws_region+':'+data_pipeline_stack_props.account_number+':*']
    ))
    ecsTaskRole.add_to_principal_policy(iam.PolicyStatement(
        actions= ["ssm:DescribeParameters",
        "ssm:GetParameters"],
        effect= iam.Effect.ALLOW,
        resources=['arn:aws:ssm:'+data_pipeline_stack_props.aws_region+':'+data_pipeline_stack_props.account_number+':*']
    ))
    ecsTaskRole.add_to_principal_policy(iam.PolicyStatement(
        actions= ["kms:Decrypt"],
        effect= iam.Effect.ALLOW,
        resources= ['arn:aws:kms:'+data_pipeline_stack_props.aws_region+':'+data_pipeline_stack_props.account_number+':*']
    ))
    ecsTaskRole.add_to_principal_policy(iam.PolicyStatement(
        actions= ["elasticfilesystem:*"],
        effect= iam.Effect.ALLOW,
        resources= ['arn:aws:elasticfilesystem:'+data_pipeline_stack_props.aws_region+':'+data_pipeline_stack_props.account_number+':*']
    ))
    ecsTaskRole.add_to_principal_policy(iam.PolicyStatement(
        actions= ["s3:*",
        "s3-object-lambda:*"],
        effect= iam.Effect.ALLOW,
        resources= ['arn:aws:s3:::*']
    ))

    return ecsTaskRole

def add_lambda_execution_role_policies(lambdaExecutionRole: iam.Role):
    lambdaExecutionRole.add_to_principal_policy(iam.PolicyStatement(
        actions= ["kms:Decrypt"],
        effect= iam.Effect.ALLOW,
        resources= ["*"]
    ))
    lambdaExecutionRole.add_to_principal_policy(iam.PolicyStatement(
        actions= ["s3:*",
        "s3-object-lambda:*"],
        effect= iam.Effect.ALLOW,
        resources= ['arn:aws:s3:::*']
    ))

    return lambdaExecutionRole
