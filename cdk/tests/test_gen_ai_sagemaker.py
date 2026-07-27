import aws_cdk as cdk
import pytest
from generative_ai_service.lib.txt2img_generative_ai_stack import (
    GenerativeAITxt2ImgSagemakerStack,
)
from generative_ai_service.lib.txt2txt_generative_ai_stack import (
    GenerativeAITxt2TxtSagemakerStack,
)


MODEL_INFO = {
    "instance_type": "ml.g5.xlarge",
    "model_bucket_name": "jumpstart-cache-prod-us-west-2",
    "model_bucket_key": "models/example/",
    "model_docker_image": (
        "763104351884.dkr.ecr.us-west-2.amazonaws.com/"
        "huggingface-pytorch-inference:2.1.0"
    ),
    "region_name": "us-west-2",
}


def arn_suffix(resource):
    if isinstance(resource, str):
        return resource
    return "".join(
        part
        for part in resource["Fn::Join"][1]
        if isinstance(part, str)
    )


@pytest.mark.parametrize(
    "stack_type",
    [
        GenerativeAITxt2ImgSagemakerStack,
        GenerativeAITxt2TxtSagemakerStack,
    ],
)
def test_sagemaker_role_is_scoped_to_selected_model(stack_type):
    app = cdk.App()
    stack = stack_type(
        app,
        "GenAITest",
        model_info=dict(MODEL_INFO),
        env=cdk.Environment(account="111122223333", region="us-west-2"),
    )
    template = cdk.assertions.Template.from_stack(stack).to_json()

    roles = [
        resource
        for resource in template["Resources"].values()
        if resource["Type"] == "AWS::IAM::Role"
    ]
    assert len(roles) == 1
    assert "ManagedPolicyArns" not in roles[0]["Properties"]

    models = [
        resource
        for resource in template["Resources"].values()
        if resource["Type"] == "AWS::SageMaker::Model"
    ]
    assert len(models) == 1
    assert models[0]["Properties"]["EnableNetworkIsolation"] is True

    policies = [
        resource
        for resource in template["Resources"].values()
        if resource["Type"] == "AWS::IAM::Policy"
    ]
    statements = [
        statement
        for policy in policies
        for statement in policy["Properties"]["PolicyDocument"]["Statement"]
    ]

    assert any(
        statement["Action"] == "s3:GetObject"
        and arn_suffix(statement["Resource"]).endswith(
            ":s3:::jumpstart-cache-prod-us-west-2/models/example/*"
        )
        for statement in statements
    )
    assert any(
        statement["Action"]
        == [
            "ecr:BatchCheckLayerAvailability",
            "ecr:BatchGetImage",
            "ecr:GetDownloadUrlForLayer",
        ]
        and arn_suffix(statement["Resource"]).endswith(
            ":ecr:us-west-2:763104351884:repository/"
            "huggingface-pytorch-inference"
        )
        for statement in statements
    )

    # Endpoints must be able to deliver logs and metrics.
    assert any(
        "logs:PutLogEvents" in statement["Action"]
        and arn_suffix(statement["Resource"]).endswith(
            ":log-group:/aws/sagemaker/Endpoints/*"
        )
        for statement in statements
    )
    assert any(
        statement["Action"] == "cloudwatch:PutMetricData"
        for statement in statements
    )

    granted_actions = {
        action
        for statement in statements
        for action in (
            statement["Action"]
            if isinstance(statement["Action"], list)
            else [statement["Action"]]
        )
    }
    assert "s3:*" not in granted_actions
    assert "sagemaker:*" not in granted_actions
