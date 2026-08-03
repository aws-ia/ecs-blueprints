import streamlit as st
import json
import numpy as np
import time
import boto3
from botocore.exceptions import BotoCoreError, ClientError

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
    sm_endpoint = None
    max_attempts = 3

    for attempt in range(max_attempts):
        try:
            # Retrieve SageMaker Endpoint name from Parameter Store
            sm_endpoint = get_parameter("txt2img_sm_endpoint")
            break
        except (BotoCoreError, ClientError):
            if attempt < max_attempts - 1:
                time.sleep(2)

    if sm_endpoint is None:
        st.error(
            "Could not retrieve the SSM parameter 'txt2img_sm_endpoint' after "
            f"{max_attempts} attempts. Ensure the SageMaker JumpStart stack is "
            "deployed and the parameter exists in this region."
        )
        st.stop()

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
