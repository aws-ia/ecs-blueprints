import streamlit as st
import requests
import json
import time
import boto3

st.set_page_config(
    page_title="text generation",
    layout="wide",
    page_icon=":technologist:"
)

st.header("Generative AI Demo - Text Generation :books:")
st.caption("Using FLAN-T5-XL model from Hugging Face")

def get_parameter(name):
    ssm = boto3.client('ssm')
    param = ssm.get_parameter(Name=name,WithDecryption=True)
    return param['Parameter']['Value']

runtime = boto3.client("runtime.sagemaker")

conversation = """Customers were very excited about the wireless charging feature, but the launch has not lived up to their expectations. The phones are not reliably charging and that is frustrating since it is such a fundamental aspect of any electronic device."""

with st.spinner("Retrieving configurations..."):
    all_configs_loaded = False

    while not all_configs_loaded:
        try:
            # Retrive SageMaker Endpoint name from Parameter Store
            sm_endpoint = get_parameter("txt2txt_sm_endpoint")
            all_configs_loaded = True
        except:
            time.sleep(5)

    endpoint_name = st.sidebar.text_input("SageMaker Endpoint Name:",sm_endpoint)

    context = st.text_area("Input Context:", conversation, height=300)

    query = st.text_area("Input Query:", "Are customers happy?")
    st.caption("e.g., write a summary")

    if st.button("Generate Response", key=query):
        if endpoint_name == "" or query == "":
            st.error("Please enter a valid endpoint name and prompt!")
        else:
            with st.spinner("Wait for it..."):
                try:
                    prompt = f"{context}\n{query}"
                    response = runtime.invoke_endpoint(
                        EndpointName=endpoint_name,
                        Body=prompt,
                        ContentType="application/x-text",
                    )
                    response_body = json.loads(response["Body"].read().decode())
                    generated_text = response_body["generated_text"]
                    st.write(generated_text)

                except requests.exceptions.ConnectionError as errc:
                    st.error("Error Connecting:",errc)

                except requests.exceptions.HTTPError as errh:
                    st.error("Http Error:",errh)

                except requests.exceptions.Timeout as errt:
                    st.error("Timeout Error:",errt)

                except requests.exceptions.RequestException as err:
                    st.error("OOps: Something Else",err)

            st.success("Done!")
