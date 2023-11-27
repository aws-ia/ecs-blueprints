import json, boto3
from langchain.prompts import PromptTemplate
from langchain.llms.sagemaker_endpoint import LLMContentHandler, SagemakerEndpoint
from langchain import LLMChain
from langchain.chains.summarize import load_summarize_chain
from langchain.text_splitter import RecursiveCharacterTextSplitter
import streamlit as st
import time
import os

st.set_page_config(
    page_title="langchain",
    layout="wide",
    page_icon=":technologist:"
)

st.header("Generative AI Demo - Q&A Using Map Reduce :books:")
st.caption("Using FLAN-T5-XL model from Hugging Face")

def get_parameter(name):
    ssm = boto3.client('ssm')
    param = ssm.get_parameter(Name=name,WithDecryption=True)
    return param['Parameter']['Value']

# runtime = boto3.client("runtime.sagemaker")

class ContentHandler(LLMContentHandler):
    content_type = "application/x-text"
    accepts = "application/json"

    def transform_input(self, prompt: str, model_kwargs: dict) -> bytes:
        input_str = json.dumps({"inputs": prompt, **model_kwargs})
        return input_str.encode("utf-8")

    def transform_output(self, output: bytes) -> json:
        response_json = json.loads(output.read().decode("utf-8"))
        generated_text = response_json["generated_text"]
        generated_text = generated_text.replace('"n','')
        st.write(generated_text)
        return generated_text

def create_chunks(context):
    text_splitter = RecursiveCharacterTextSplitter(separators=["\n\n", "\n"], chunk_size=1000, chunk_overlap=50)
    docs = text_splitter.create_documents([context])
    for doc in docs:
        doc.page_content = doc.page_content.replace('\n','')

    return docs

def simple_map_reduce(context, map_query, reduce_query, endpoint_name, region_name):
    docs = create_chunks(context)
    content_handler = ContentHandler()
    llm = SagemakerEndpoint(
                    endpoint_name = endpoint_name,
                    region_name= region_name,
                    content_handler=content_handler
                )

    map_template = """In the following text find all answers to the question which is delimited by ```. {text}. Provide answer as complete sentence.""" + """```""" + map_query + """```\n"""
    map_prompt = PromptTemplate(template=map_template,
                                input_variables=["text"])
    map_chain = LLMChain(llm=llm,prompt=map_prompt)

    output_list =[]
    for doc in docs:
        output = map_chain.run(doc)
        output_list.append(output)

    reduce_template = """In the following comma separated text list, find all answers to the question which is delimited by ```. {text}. Provide answer as complete sentence.""" + """```""" + reduce_query + """```\n"""
    reduce_prompt = PromptTemplate(template=reduce_template,
                                input_variables=["text"])
    reduce_chain = LLMChain(llm=llm,prompt=reduce_prompt)
    reduce_output = reduce_chain.run(','.join(output_list))
    return {"map_answers":output_list, "reduce_answer":reduce_output}

def langchain_map_reduce(context, map_query, reduce_query, endpoint_name, region_name):
    content_handler = ContentHandler()

    map_template = """{text}
    Question: {question}
    Answer:"""
    map_prompt_template = PromptTemplate(template=map_template, input_variables=["text","question"])

    combine_template = """{text} """ + """ Question: """ + reduce_query + """ Answer:"""

    combine_prompt_template = PromptTemplate(template=combine_template, input_variables=["text"])

    llm = SagemakerEndpoint(
        endpoint_name = endpoint_name,
        region_name= region_name,
        content_handler=content_handler
    )

    summary_chain = load_summarize_chain(
        llm=llm,
        chain_type="map_reduce",
        map_prompt=map_prompt_template,
        combine_prompt=combine_prompt_template,
        verbose=True,
        return_intermediate_steps=True
    )

    # split pharagraph
    docs = create_chunks(context)
    summary = summary_chain({"input_documents": docs, "question": map_query, 'token_max': 10000}, return_only_outputs=True)
    return summary.get("output_text","**no response found**")

conversation = """
We are introducing ECS Blueprints for AWS Cloud Development Kit (AWS CDK) that makes it easier and faster to build container workloads for the Amazon Elastic Container Service (Amazon ECS). ECS Blueprints is a collection of Infrastructure as Code (IaC) open-source modules that help you configure and deploy container workloads on top of Amazon ECS cluster. Customers can use ECS Blueprints not only for beginning Amazon ECS journey but also for building specific workload like frontend service with Application Load Balancer (ALB) on the existing cluster. Also, ECS Blueprints shows the best practices for each scenario and provides reference architectures and solution patterns. This allows customers to speed up building Amazon ECS workloads because ECS Blueprints addresses end-to-end requirements for specific scenarios. Furthermore, customers can easily customize ECS Blueprints templates for their use cases, which is covered in detail in this post. AWS CDK is an open-source software development framework that models and provisions cloud infrastructure using familiar programming languages. Therefore, developers can use familiar languages such as TypeScript, Python, and Java to provision infrastructure and to build business logic at the same time. Additionally, since AWS CDK's built-in components are a high-level abstraction consisting of one or more AWS resources, customers can quickly configure and deploy multiple environments by using custom values for parameters defined by AWS CDK constructs. While this post is focused on ECS Blueprints with AWS CDK, ECS Blueprints with Terraform is also available in the same repository and implements similar concepts in Terraform. Containers are a de facto standard for packaging and deploying applications. Containers include all the application dependencies and boot up consistently across machines from developer laptop to production environments. The portability of containers enables customers to build end-to-end automated software delivery pipelines and enables them to ship software frequently and quickly. However, for many new customers, the learning curve and skills needed to attain these benefits can be quite steep. They have to learn container image building, understand container orchestration such as Amazon ECS, create deployment artifacts, instrument for observability and security, and set up the continuous integration (CI) and continuous deployment (CD) pipelines. Even though fully managed services such as Amazon ECS and AWS Fargate eliminate a lot of the heavy lift, there's still quite a broad set of skills that new users need to ramp up. With ECS Blueprints, we want new users to achieve benefits of container-based modernization in hours rather than months. The blueprints are meant to give new users a jumpstart, and enable them to learn-by-doing. With ECS Blueprints, we aspire to codify best practices, well-designed architecture patterns, and provide end-to-end solutions addressing CI/CD, observability, security, and cost efficiency. In this post, we'll provide details on the ECS Blueprints that use AWS Fargate which is a serverless container engine as compute and AWS CDK as the infrastructure-as-code language.

We are happy to announce new features in AWS Fault Injection Simulator (FIS) that allow you to inject a variety faults into workloads running in Amazon Elastic Container Service (Amazon ECS) and Amazon Elastic Kubernetes Service (Amazon EKS). This blog shows how to use new AWS FIS actions with Amazon ECS. AWS Fault Injection Simulator (FIS) is a fully managed service that helps you test your applications for resilience to failures. AWS FIS follows the principles of chaos engineering, which allows you to simulate failures in your AWS environment. These can be network outages, infrastructure failure, and service disruptions. AWS FIS experiments help you identify and fix potential problems before they cause outages in production. AWS FIS has added six new fault injection actions that target Amazon ECS workloads. New Amazon ECS task actions include stressing a ECS task's CPU (Central Processing Unit), I/O, killing a process, and network actions like network blackhole, latency, and packet loss. These actions make it easy for you to evaluate your application's reliability and resilience across a wide range of failure scenarios. If you are using AWS Fargate, you have the ability to conduct CPU and I/O actions.

November 2023: AWS Fargate now supports having both SOCI and non SOCI enabled containers in the same Amazon ECS task, therefore the “All container images within an Amazon ECS Task need a SOCI Index Manifest” restriction no longer applies. To learn more see the whats new post. AWS Fargate, a serverless compute engine for containerized workloads, now supports lazy loading container images that have been indexed using Seekable OCI (SOCI). Lazy loading container images with SOCI reduces the time taken to launch Amazon Elastic Container Service (Amazon ECS) Tasks on AWS Fargate. Donnie Prakoso's launch post provides details on how to get started with AWS Fargate and SOCI, therefore is recommended before reading this post. In this post, we'll dive into SOCI and how it can index a container image without modifying its contents or requiring a change to existing tools or workflows. We will discuss the SOCI snapshotter, a remote containerd snapshotter that leverages SOCI Indexes to lazy load container images. And finally, we will cover some of the caveats when using SOCI on AWS Fargate. In containerd the component that manages the container's filesystem is called a snapshotter. The default snapshotter, overlayfs, pulls and decompresses the entire container image before a container can be started. With lazy loading snapshotters (such as stargz or SOCI snapshotter), the container starts without downloading the entire container image and instead lazily loads files from an OCI compatible registry, like Amazon Elastic Container Registry (Amazon ECR). As the container is started without waiting for the full container image to be downloaded, the launch time is often shorter when compared to overlayfs. With overlayfs there is a correlation between the time taken to pull an image and the size of the container image. Therefore, with lazy loading snapshotters the speedup relative to overlayfs increases as the container image size increases. Before the SOCI snapshotter can lazily load a container image it needs to have metadata about the images' contents. Container images consist of several container image layers, stored in an OCI compatible registry as compressed tarballs. For the SOCI snapshotter to be able to lazy load the container image, it needs to know which files are in each layer, where within the compressed tarball they are stored, and how to decompress just the files that the application needs. In SOCI all this metadata is stored in a SOCI Index.
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

    map_query = st.text_area("Map Query:", "What is being introduced in this blog text?")

    reduce_query = st.text_area("Reduce Query:", "What is the common topic?")

    if st.button("Generate Response", key=map_query):
        if endpoint_name == "" or map_query == "":
            st.error("Please enter a valid endpoint name and prompt!")
        else:
            with st.spinner("Wait for it..."):
                generated_text = simple_map_reduce(context, map_query, reduce_query, endpoint_name, os.getenv('region'))
                st.info(generated_text)

            st.success("Done!")
