import boto3
import streamlit as st
import json
import uuid
from typing import Dict, Any, List, Optional, Generator

# Constants
MODEL_ID = 'anthropic.claude-3-haiku-20240307-v1:0'
KNOWLEDGE_BASE_PARAM = "knowledge_base_id"
MODEL_ARN = f"arn:aws:bedrock:us-west-2::foundation-model/{MODEL_ID}"
INITIAL_MESSAGE = "Hello, Builders! Ask me any questions you have about AWS re:Invent sessions."

# Initialize Streamlit session state
if "messages" not in st.session_state:
    st.session_state["messages"] = [{"role": "assistant", "content": INITIAL_MESSAGE}]
if "session_id" not in st.session_state:
    st.session_state["session_id"] = None

@st.cache_data
def get_parameter(name: str) -> Optional[str]:
    """Retrieve a parameter from AWS Systems Manager Parameter Store."""
    try:
        ssm = boto3.client('ssm')
        param = ssm.get_parameter(Name=name, WithDecryption=True)
        return param['Parameter']['Value']
    except Exception as e:
        st.error(f"Error retrieving parameter: {e}")
        return None

def invoke_bedrock_stream(client: Any, system_prompt: str, user_prompt: str) -> Generator[str, None, None]:
    body = json.dumps({
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": 4000,
        "temperature": 0.1,
        "top_p": 0.9,
        "system": system_prompt,
        "messages": [{"role": "user", "content": user_prompt}]
    })

    try:
        response = client.invoke_model_with_response_stream(
            body=body,
            modelId=MODEL_ID,
            accept='application/json',
            contentType='application/json'
        )
        for event in response.get('body'):
            chunk = json.loads(event['chunk']['bytes'])
            if chunk['type'] == 'content_block_delta':
                if chunk['delta']['type'] == 'text_delta':
                    yield chunk['delta']['text']
            elif chunk['type'] == 'content_block_stop':
                break
    except Exception as e:
        st.error(f"Error invoking Bedrock model: {e}")
        yield ""

def get_prompt_template(retrieved_passages: List[str]) -> str:
    """Return the improved prompt template for the AI assistant with response formatting."""
    return f"""
    You are an AI assistant answering questions about AWS re:Invent 2024 session information and general queries. 
    Your task is to analyze the user's question, categorize it, and provide an appropriate response.

    First, analyze the user's question and categorize it into one of the following:
    1. General question
    2. re:Invent session recommendation question
    3. re:Invent session information question

    Then, based on your analysis, prepare a response following these guidelines:

    1. For general questions:
       - Ignore the content in the retrieved passages.
       - Provide a direct answer to the question based on your general knowledge.
       - Do not include any uncertain information or speculation.
       - If the question is outside your knowledge base, politely state that you don't have that information.

    2. For re:Invent session recommendation questions:
       - Use the information from the retrieved passages to recommend sessions.
       - Prioritize recommendations based on:
         a) Exact matches in the "Related AWS Services" field (highest priority)
         b) Relevance in the "Description" and "Title" fields
         c) Relevance to the Topic and Areas of Interest
       - Always include "Description", "Time" and "Venue" information for recommended sessions and summary it.

    3. For re:Invent session information questions:
       - Use the information from the retrieved passages to provide detailed session information.
       - Focus on the following aspects:
         - Description
         - Areas of Interest
         - Session Type
         - Prerequisites
         - Key Points
         - Related AWS Services
       - Provide accurate Venue and Date/Time information when asked about schedules and locations.
       - If the search results lack a clear answer, explicitly state the inability to find exact information.

    General guidelines:
    - Provide concise answers with all relevant information.
    - Address the core question directly without unnecessary preamble or conclusion.
    - Always base your answers on the provided data and refrain from offering uncertain information.
    - Verify user assertions against search results; don't assume user statements are factual.

    Here are the retrieved passages:
    {retrieved_passages}

    IMPORTANT: Your final response should only contain the actual answer to the user's question. 
    Do not include any explanation of your thought process, categorization, or analysis in the final response. 
    
    Format your response as follows:
    [QUESTION_TYPE]
    The type of question (GENERAL, REINVENT_RECOMMENDATION, or REINVENT_INFORMATION)
    [/QUESTION_TYPE]
    [RESPONSE]
    Your actual response here, without any preamble or explanation of your thought process.
    [/RESPONSE]

    Everything outside the [RESPONSE] tags will be discarded, so ensure your complete answer is within these tags.
    """

def retrieve_from_knowledge_base(client: Any, knowledge_base_id: str, prompt: str) -> List[Dict[str, Any]]:
    """Retrieve relevant passages from the knowledge base."""
    with st.spinner("Retrieving relevant information from the knowledge base...."):
        try:
            response = client.retrieve(
                knowledgeBaseId=knowledge_base_id,
                retrievalQuery={
                    'text': prompt
                },
                retrievalConfiguration={
                    'vectorSearchConfiguration': {
                        'numberOfResults': 10
                    }
                }
            )
            return response.get('retrievalResults', [])
        except Exception as e:
            st.error(f"Error retrieving from knowledge base: {e}")
            return []

def main():
    st.title("💬 Chat with Knowledge Base")
    st.caption("Using Amazon Bedrock with RAG integration")

    for msg in st.session_state.messages:
        st.chat_message(msg["role"]).write(msg["content"])

    if prompt := st.chat_input():
        st.chat_message("user").write(prompt)
        st.session_state.messages.append({"role": "user", "content": prompt})

        knowledge_base_id = get_parameter(KNOWLEDGE_BASE_PARAM)
        if not knowledge_base_id:
            st.info("Something is wrong with parameter store")
            st.stop()
        
        agent_client = boto3.client('bedrock-agent-runtime')
        bedrock_runtime_client = boto3.client('bedrock-runtime')

        try:
            # Retrieve relevant passages from the knowledge base
            retrieved_results = retrieve_from_knowledge_base(agent_client, knowledge_base_id, prompt)
            
            # Extract and format the retrieved passages
            retrieved_passages = [result['content']['text'] for result in retrieved_results]
            formatted_passages = "\n\n".join(f"Passage {i+1}:\n{passage}" for i, passage in enumerate(retrieved_passages))

            # Generate the final response using the invoke_model API
            system_prompt = get_prompt_template(formatted_passages)
            
            message_placeholder = st.chat_message("assistant").empty()
            full_response = ""
            for chunk in invoke_bedrock_stream(bedrock_runtime_client, system_prompt, prompt):
                full_response += chunk
                message_placeholder.markdown(full_response + "▌")

            # Extract question type and response
            import re
            question_type_match = re.search(r'\[QUESTION_TYPE\](.*?)\[/QUESTION_TYPE\]', full_response, re.DOTALL)
            response_match = re.search(r'\[RESPONSE\](.*?)\[/RESPONSE\]', full_response, re.DOTALL)
            
            question_type = question_type_match.group(1).strip() if question_type_match else "UNKNOWN"
            final_response = response_match.group(1).strip() if response_match else "I apologize. There was an issue generating an appropriate response."

            message_placeholder.markdown(final_response)
            
            st.session_state.messages.append({"role": "assistant", "content": final_response})

            # Display citations only for non-general questions
            if question_type != "GENERAL":
                with st.expander("Data Sources"):
                    for i, result in enumerate(retrieved_results, 1):
                        content = result['content']['text']
                        st.markdown(f"**Source {i}:**")
                        st.text_area(f"Chunk Data {i}", value=content, height=150, disabled=True)
                        st.markdown("---")

        except boto3.exceptions.Boto3Error as e:
            print(f"Boto3 Error: {e}")
            if 'Session with Id' in str(e) and 'is not valid' in str(e):
                st.session_state["session_id"] = str(uuid.uuid4())
                st.warning("Session has expired. Starting a new session. Please enter your question again.")
            else:
                st.error("An error occurred while processing the response. Please check the logs for details.")
            
            msg = "I encountered an issue while processing the response. Could you please rephrase your prompt or try a different question?"
            st.session_state.messages.append({"role": "assistant", "content": msg})
            st.chat_message("assistant").write(msg)

if __name__ == "__main__":
    main()