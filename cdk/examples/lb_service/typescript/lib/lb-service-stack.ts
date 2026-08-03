import { CfnOutput, Stack, StackProps } from 'aws-cdk-lib';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as ecs from 'aws-cdk-lib/aws-ecs';
import * as ecsPatterns from 'aws-cdk-lib/aws-ecs-patterns';
import { Construct } from 'constructs';

export const CONTAINER_IMAGE =
  'public.ecr.aws/aws-containers/ecsdemo-frontend:776fd50';
export const CONTAINER_PORT = 3000;
export const DESIRED_COUNT = 3;

/**
 * The smallest useful ECS web service: a VPC, a Fargate cluster, and one
 * service behind a public Application Load Balancer. The stack owns every
 * resource it uses, so `cdk deploy` and `cdk destroy` are complete on their
 * own — no shared core stack and no lookups of existing resources.
 */
export class LoadBalancedServiceStack extends Stack {
  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);

    const vpc = new ec2.Vpc(this, 'Vpc', {
      ipAddresses: ec2.IpAddresses.cidr('10.20.0.0/16'),
      maxAzs: 2,
      natGateways: 1,
    });

    const cluster = new ecs.Cluster(this, 'Cluster', { vpc });

    const service = new ecsPatterns.ApplicationLoadBalancedFargateService(
      this,
      'Service',
      {
        cluster,
        cpu: 256,
        memoryLimitMiB: 512,
        desiredCount: DESIRED_COUNT,
        publicLoadBalancer: true,
        circuitBreaker: { rollback: true },
        minHealthyPercent: 100,
        taskImageOptions: {
          containerName: 'ecsdemo-frontend',
          image: ecs.ContainerImage.fromRegistry(CONTAINER_IMAGE),
          containerPort: CONTAINER_PORT,
        },
      }
    );

    // The demo app serves its landing page on '/', so the ALB uses it as the
    // health check. Tasks that stop answering are replaced automatically.
    service.targetGroup.configureHealthCheck({ path: '/' });

    new CfnOutput(this, 'ApplicationUrl', {
      value: `http://${service.loadBalancer.loadBalancerDnsName}`,
    });
  }
}
