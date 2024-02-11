import streamlit as st
import json
import numpy as np
import time
import boto3

st.set_page_config(
    page_title="image generation",
    layout="wide",
    page_icon=":technologist:"
)

st.header("Generative AI Demo - Image Generation :frame_with_picture:")
st.caption("Using Stable Diffusion model from Hugging Face")

def get_parameter(name):
    ssm = boto3.client('ssm')
    param = ssm.get_parameter(Name=name,WithDecryption=True)
    return param['Parameter']['Value']

runtime = boto3.client("runtime.sagemaker")

with st.spinner("Retrieving configurations..."):
    all_configs_loaded = False

    while not all_configs_loaded:
        try:
            # Retrive SageMaker Endpoint name from Parameter Store
            sm_endpoint = get_parameter("txt2img_sm_endpoint")
            all_configs_loaded = True
        except:
            time.sleep(5)

    endpoint_name = st.sidebar.text_input("SageMaker Endpoint Name:", sm_endpoint)


prompt = st.text_area("Input Image description:", """Swimming Chihuahua""")

if st.button("Generate image"):
    if endpoint_name == "" or prompt == "":  # or url == "":
        st.error("Please enter a valid endpoint name and prompt!")
    else:
        with st.spinner("Wait for it..."):
            try:
                response = runtime.invoke_endpoint(
                    EndpointName=endpoint_name,
                    Body=prompt,
                    ContentType="application/x-text",
                )
                response_body = json.loads(response["Body"].read().decode())
                image_array = response_body["generated_image"]
                st.image(np.array(image_array))

            except runtime.exceptions.InternalFailure as erri:
                st.error("InternalFailure:", erri)

            except runtime.exceptions.ServiceUnavailable as errs:
                st.error("ServiceUnavailable:", errs)

            except runtime.exceptions.ValidationError as errv:
                st.error("ValidationError:", errv)

            except runtime.exceptions.ModelError as errm:
                st.error("ModelError", errm)

            except runtime.exceptions.ModelNotReadyException as err:
                st.error("ModelNotReadyException", err)

        st.success("Done!")
