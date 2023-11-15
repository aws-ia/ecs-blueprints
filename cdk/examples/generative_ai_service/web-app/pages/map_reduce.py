import json, boto3
from langchain.prompts import PromptTemplate
from langchain.llms import SagemakerEndpoint
from langchain.llms.sagemaker_endpoint import LLMContentHandler
from langchain.chains.summarize import load_summarize_chain
from langchain.text_splitter import RecursiveCharacterTextSplitter
import streamlit as st
import time
import os

st.header("Generative AI Demo - Q&A Using Map Reduce")
st.caption("Using FLAN-T5-XL model from Hugging Face")

def get_parameter(name):
    ssm = boto3.client('ssm')
    param = ssm.get_parameter(Name=name,WithDecryption=True)
    return param['Parameter']['Value']

class ContentHandlerTextSummarization(LLMContentHandler):
    content_type = "application/x-text"
    accepts = "application/json"

    def transform_input(self, prompt: str, model_kwargs={}) -> bytes:
        input_str = json.dumps({"inputs": prompt, **model_kwargs})
        return input_str.encode("utf-8")

    def transform_output(self, output: bytes) -> json:
        response_json = json.loads(output.read().decode("utf-8"))
        generated_text = response_json["generated_text"]
        return generated_text
    
# split pharagraph
def create_chunks(context):
    text_splitter = RecursiveCharacterTextSplitter(separators=["\n\n", "\n"], chunk_size=1000, chunk_overlap=100)
    docs = text_splitter.create_documents([context])
    return docs

def invoke_map_reduce(context, query, endpoint_name, region_name):
    content_handler = ContentHandlerTextSummarization()
    map_prompt = """{text}\n""" + query + """\nMap answer:"""
    map_prompt_template = PromptTemplate(
                        template=map_prompt, 
                        input_variables=["query"]
                      )
    
    combine_prompt = """{text} Combined answer:""" 
    
    combine_prompt_template = PromptTemplate(
                            template=combine_prompt, 
                            input_variables=["text"]
                          )
    
    summary_model = SagemakerEndpoint(
                    endpoint_name = endpoint_name,
                    region_name= region_name,
                    content_handler=content_handler
                )

    summary_chain = load_summarize_chain(llm=summary_model,
                                        chain_type="map_reduce", 
                                        map_prompt=map_prompt_template,
                                        combine_prompt=combine_prompt_template,
                                        verbose=True
                                        )

    docs = create_chunks(context)
    summary = summary_chain({"input_documents": docs, 'token_max': 500}, return_only_outputs=True)
    return(summary.get("output_text","**no response found**"))


runtime = boto3.client("runtime.sagemaker")

conversation = """
We are introducing ECS Blueprints for AWS Cloud Development Kit (AWS CDK) that makes it easier and faster to build container workloads for the Amazon Elastic Container Service (Amazon ECS). ECS Blueprints is a collection of Infrastructure as Code (IaC) open-source modules that help you configure and deploy container workloads on top of Amazon ECS cluster. Customers can use ECS Blueprints not only for beginning Amazon ECS journey but also for building specific workload like frontend service with Application Load Balancer (ALB) on the existing cluster. Also, ECS Blueprints shows the best practices for each scenario and provides reference architectures and solution patterns. This allows customers to speed up building Amazon ECS workloads because ECS Blueprints addresses end-to-end requirements for specific scenarios. Furthermore, customers can easily customize ECS Blueprints templates for their use cases, which is covered in detail in this post.

We are happy to announce new features in AWS Fault Injection Simulator (FIS) that allow you to inject a variety faults into workloads running in Amazon Elastic Container Service (Amazon ECS) and Amazon Elastic Kubernetes Service (Amazon EKS). This blog shows how to use new AWS FIS actions with Amazon ECS. AWS Fault Injection Simulator (FIS) is a fully managed service that helps you test your applications for resilience to failures. AWS FIS follows the principles of chaos engineering, which allows you to simulate failures in your AWS environment. These can be network outages, infrastructure failure, and service disruptions. AWS FIS experiments help you identify and fix potential problems before they cause outages in production.

Customers running applications on Amazon Elastic Container Service (ECS) with AWS Fargate can now leverage Seekable OCI (SOCI), a technology open sourced by AWS that helps applications deploy and scale out faster by enabling the containers to start without waiting for the entire container image to be downloaded. Most methods for launching containers download the entire container image from a remote container registry before starting the container. Waiting for the entire image to download is unnecessary as in many cases only a small portion of it is needed for startup. SOCI reduces this wait time by lazily loading the image data in parallel to application startup, enabling containers to start with only a fraction of the image.
"""

with st.spinner("Retrieving configurations..."):
    all_configs_loaded = False

    while not all_configs_loaded:
        try:
            # Retrive SageMaker Endpoint name from Parameter Store
            sm_endpoint = get_parameter("txt2txt_sm_endpoint")
            all_configs_loaded = True
        except:
            time.sleep(5)

    endpoint_name = st.sidebar.text_input("SageMaker Endpoint Name:", sm_endpoint)

    context = st.text_area("Input Context:", conversation, height=700)

    query = st.text_area("Input Query:", "What are being introduced?")

    if st.button("Generate Response", key=query):
        if endpoint_name == "" or query == "":
            st.error("Please enter a valid endpoint name and prompt!")
        else:
            with st.spinner("Wait for it..."):
                generated_text = invoke_map_reduce(context, query, endpoint_name, os.getenv('region'))
                st.write(generated_text)

            st.success("Done!")
