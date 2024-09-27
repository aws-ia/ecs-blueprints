import boto3.exceptions
import streamlit as st
import boto3
import json
from botocore.exceptions import ClientError

st.caption("Using Calude 3 Haiku from Anthropic")

@st.cache_data
def get_parameter(name):
    try:
        ssm = boto3.client('ssm')
        param = ssm.get_parameter(Name=name,WithDecryption=True)
        return param['Parameter']['Value']
    except:
        return

st.title("💬 Chat")

if "foundation_messages" not in st.session_state:
    st.session_state["foundation_messages"] = [{"role": "assistant", "content": "Ask me something about reinvent 2024?"}]

for msg in st.session_state.foundation_messages:
    st.chat_message(msg["role"]).write(msg["content"])

if prompt := st.chat_input():
    st.chat_message("user").write(prompt)
    st.session_state.foundation_messages.append(
        {
            "role": "user",
            "content": prompt
        }
    )

    # Use the native inference API to send a text message to Anthropic Claude.

    # Create a Bedrock Runtime client in the AWS Region of your choice.
    client = boto3.client("bedrock-runtime", region_name="us-east-1")

    # Set the model ID, e.g., Claude 3 Haiku.
    model_id = "anthropic.claude-3-haiku-20240307-v1:0"

    # Format the request payload using the model's native structure.
    native_request = {
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": 512,
        "temperature": 0.5,
        "messages": [
            {
                "role": "user",
                "content": [{"type": "text", "text": prompt}],
            }
        ],
    }

    # Convert the native request to JSON.
    request = json.dumps(native_request)

    try:
        # Invoke the model with the request.
        response = client.invoke_model(modelId=model_id, body=request)

    except (ClientError, Exception) as e:
        msg = f"ERROR: Can't invoke '{model_id}'. Reason: {e}"
        st.session_state.foundation_messages.append(
            {
                "role": "assistant",
                "content": msg
            }
        )
        st.chat_message("assistant").write(msg)

    # Decode the response body.
    model_response = json.loads(response["body"].read())

    # Extract and print the response text.
    msg = model_response["content"][0]["text"]
    st.session_state.foundation_messages.append(
        {
            "role": "assistant",
            "content": msg
        }
    )
    st.chat_message("assistant").write(msg)
