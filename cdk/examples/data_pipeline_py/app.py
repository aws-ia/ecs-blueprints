#!/usr/bin/env python3
import os
import aws_cdk as cdk

from lib.sfn_ecs_blueprint_stack import SfnEcsBlueprintStack


app = cdk.App()

SfnEcsBlueprintStack(app, "SfnEcsBlueprintStack",
                         
    env=cdk.Environment(account=os.getenv('CDK_DEFAULT_ACCOUNT'), region=os.getenv('CDK_DEFAULT_REGION')),

    # Uncomment the next line if you know exactly what Account and Region you
    # want to deploy the stack to. */

    #env=cdk.Environment(account='123456789012', region='us-east-1'),

    )

app.synth()
