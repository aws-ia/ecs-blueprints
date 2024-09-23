import boto3.exceptions
import streamlit as st
import boto3
import uuid

st.caption("Using Amazon Bedrock with RAG integration")

@st.cache_data
def get_parameter(name):
    try:
        ssm = boto3.client('ssm')
        param = ssm.get_parameter(Name=name,WithDecryption=True)
        return param['Parameter']['Value']
    except:
        return

st.title("💬 Chat")

if "messages" not in st.session_state:
    st.session_state["messages"] = [{"role": "assistant", "content": "Ask me something about reinvent 2024?"}]

for msg in st.session_state.messages:
    st.chat_message(msg["role"]).write(msg["content"])

if prompt := st.chat_input():
    st.chat_message("user").write(prompt)
    st.session_state.messages.append(
        {
            "role": "user",
            "content": prompt
        }
    )

    agent_alias_id = get_parameter("agent_alias_id")
    agent_id = get_parameter("agent_id")

    if not agent_alias_id and agent_id:
        st.info("Something is not wrong with parameter store")
        st.stop()
    client = boto3.client('bedrock-agent-runtime', region_name='us-east-1')
    agent_response = client.invoke_agent(
        inputText=prompt,
        agentId=agent_id,
        agentAliasId=agent_alias_id,
        sessionId=str(uuid.uuid1())
    )
    try:
        for event in agent_response['completion']:
            chunks = event.get('chunk').get('attribution').get('citations')
            for chunk in chunks:
                msg = chunk['generatedResponsePart']['textResponsePart']['text']
                st.session_state.messages.append(
                    {
                        "role": "assistant",
                        "content": msg
                    }
                )
                st.chat_message("assistant").write(msg)
    except:
            msg = "Please give me a better prompt"
            st.session_state.messages.append(
                {
                    "role": "assistant",
                    "content": msg
                }
            )
            st.chat_message("assistant").write(msg)
