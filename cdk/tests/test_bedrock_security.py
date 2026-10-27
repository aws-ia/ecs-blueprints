import json

import aws_cdk as cdk

from generative_ai_rag.lib.bedrock_stack import create_private_vector_collection


def test_bedrock_vector_collection_has_no_dashboard_endpoint():
    app = cdk.App()
    stack = cdk.Stack(app, "BedrockSecurity")
    create_private_vector_collection(stack)

    template = cdk.assertions.Template.from_stack(stack).to_json()
    network_policy = next(
        resource
        for resource in template["Resources"].values()
        if resource["Type"] == "AWS::OpenSearchServerless::SecurityPolicy"
        and resource["Properties"]["Type"] == "network"
    )
    policy = json.loads(network_policy["Properties"]["Policy"])

    # The collection endpoint must remain network-reachable for the construct's
    # non-VPC index-creation Lambda; the dashboard endpoint must not be exposed.
    resource_types = {
        rule["ResourceType"]
        for statement in policy
        for rule in statement["Rules"]
    }
    assert resource_types == {"collection"}
    assert "dashboard" not in resource_types
