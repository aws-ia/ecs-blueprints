import { Effect, ManagedPolicy, Policy, PolicyStatement, Role } from "aws-cdk-lib/aws-iam";

export function addStepFunctionRolePolicies(account: String, region: String, stepFunctionExecutionRole: Role) {
    stepFunctionExecutionRole.addToPrincipalPolicy(new PolicyStatement({
        actions:["ecs:RunTask"],
        effect: Effect.ALLOW,
        resources: [`arn:aws:ecs:${region}:${account}:task-definition/*`]
    }))
    stepFunctionExecutionRole.addToPrincipalPolicy(new PolicyStatement({
        actions: ["logs:CreateLogDelivery",
        "logs:GetLogDelivery",
        "logs:UpdateLogDelivery",
        "logs:DeleteLogDelivery",
        "logs:ListLogDeliveries",
        "logs:PutResourcePolicy",
        "logs:DescribeResourcePolicies",
        "logs:DescribeLogGroups"],
        effect: Effect.ALLOW,
        resources: ["*"]
    }))
    stepFunctionExecutionRole.addToPrincipalPolicy(new PolicyStatement({
        actions: ["xray:PutTraceSegments",
        "xray:PutTelemetryRecords",
        "xray:GetSamplingRules",
        "xray:GetSamplingTargets"],
        effect: Effect.ALLOW,
        resources: ["*"]
    }))
}

export function addEcsTaskExecutionRolePolicies(account: String, region: String, ecsTaskExecutionRole: Role) {
    ecsTaskExecutionRole.addToPrincipalPolicy(new PolicyStatement({
        actions: ["ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"],
        effect: Effect.ALLOW,
        resources: [`arn:aws:ecr:${region}:${account}:*`]
    }))
    ecsTaskExecutionRole.addToPrincipalPolicy(new PolicyStatement({
        actions: ["logs:CreateLogStream",
        "logs:PutLogEvents"],
        effect: Effect.ALLOW,
        resources: ["*"]
    }))
    ecsTaskExecutionRole.addToPrincipalPolicy(new PolicyStatement({
        actions: ["ec2:AuthorizeSecurityGroupIngress",
        "ec2:Describe*"],
        effect: Effect.ALLOW,
        resources: [`arn:aws:ec2:${region}:${account}:*`]
    }))
    ecsTaskExecutionRole.addToPrincipalPolicy(new PolicyStatement({
        actions: ["elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
        "elasticloadbalancing:DeregisterTargets",
        "elasticloadbalancing:Describe*",
        "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
        "elasticloadbalancing:RegisterTargets"],
        effect: Effect.ALLOW,
        resources: [`arn:aws:elasticloadbalancing:${region}:${account}:*`]
    }))
}

export function addEcsTaskRolePolicies(account: String, region: String, ecsTaskRole: Role) {
    ecsTaskRole.addToPrincipalPolicy(new PolicyStatement({
        actions: ["states:*"],
        effect: Effect.ALLOW,
        resources: [`arn:aws:states:${region}:${account}:*`]
    }))
    ecsTaskRole.addToPrincipalPolicy(new PolicyStatement({
        actions: ["ssm:DescribeParameters",
        "ssm:GetParameters"],
        effect: Effect.ALLOW,
        resources:[`arn:aws:ssm:${region}:${account}:*`]
    }))
    ecsTaskRole.addToPrincipalPolicy(new PolicyStatement({
        actions: ["kms:Decrypt"],
        effect: Effect.ALLOW,
        resources: [`arn:aws:kms:${region}:${account}:*`]
    }))
    ecsTaskRole.addToPrincipalPolicy(new PolicyStatement({
        actions: ["elasticfilesystem:*"],
        effect: Effect.ALLOW,
        resources: [`arn:aws:elasticfilesystem:${region}:${account}:*`]
    }))
    ecsTaskRole.addToPrincipalPolicy(new PolicyStatement({
        actions: ["s3:*",
        "s3-object-lambda:*"],
        effect: Effect.ALLOW,
        resources: [`arn:aws:s3:::*`]
    }))
}

export function addLambdaExecutionRolePolicies(account: String, region: String, lambdaExecutionRole: Role) {
    lambdaExecutionRole.addToPrincipalPolicy(new PolicyStatement({
        actions: ["kms:Decrypt"],
        effect: Effect.ALLOW,
        resources: ["*"]
    }))
    lambdaExecutionRole.addToPrincipalPolicy(new PolicyStatement({
        actions: ["s3:*",
        "s3-object-lambda:*"],
        effect: Effect.ALLOW,
        resources: [`arn:aws:s3:::*`]
    }))
}
