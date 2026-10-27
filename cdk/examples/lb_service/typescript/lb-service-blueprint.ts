#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { LoadBalancedServiceStack } from './lib/lb-service-stack';

const app = new cdk.App();
new LoadBalancedServiceStack(app, 'LoadBalancedServiceTs', {
  /* The stack creates its own VPC and never looks up existing resources, so
   * it synthesizes without an account or Region. When these variables are
   * unset (for example in CI), the template stays environment-agnostic. */
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region: process.env.CDK_DEFAULT_REGION,
  },
});
