import { App } from 'aws-cdk-lib'
import { Match, Template } from 'aws-cdk-lib/assertions'
import { LoadBalancedServiceStack } from '../lib/lb-service-stack'

function synth(): Template {
  const app = new App()
  const stack = new LoadBalancedServiceStack(app, 'LoadBalancedServiceTest')
  return Template.fromStack(stack)
}

test('exposes the service through an internet-facing load balancer', () => {
  const template = synth()

  template.hasResourceProperties('AWS::ElasticLoadBalancingV2::LoadBalancer', {
    Scheme: 'internet-facing',
    Type: 'application',
  })
  template.hasResourceProperties('AWS::ElasticLoadBalancingV2::TargetGroup', {
    HealthCheckPath: '/',
  })
})

test('runs three Fargate tasks with rollback on failed deployments', () => {
  const template = synth()

  template.hasResourceProperties('AWS::ECS::Service', {
    DesiredCount: 3,
    LaunchType: 'FARGATE',
    DeploymentConfiguration: Match.objectLike({
      DeploymentCircuitBreaker: { Enable: true, Rollback: true },
      MinimumHealthyPercent: 100,
    }),
  })
})

test('pins the demo container image and its port', () => {
  const template = synth()

  template.hasResourceProperties('AWS::ECS::TaskDefinition', {
    ContainerDefinitions: Match.arrayWith([
      Match.objectLike({
        Name: 'ecsdemo-frontend',
        Image: 'public.ecr.aws/aws-containers/ecsdemo-frontend:776fd50',
        PortMappings: Match.arrayWith([
          Match.objectLike({ ContainerPort: 3000 }),
        ]),
      }),
    ]),
  })
})
