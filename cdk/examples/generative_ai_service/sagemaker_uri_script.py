import sagemaker
from sagemaker import image_uris, model_uris

session = sagemaker.Session()

def get_sagemaker_uris(model_id, instance_type, region_name):

    # model_id: a unique identifier for the JumpStart model
    MODEL_VERSION = "*"  # latest version
    SCOPE = "inference"

    # Retrieve Amazon ECR URI for pre-built SageMaker Docker image
    inference_image_uri = image_uris.retrieve(
        region=region_name,
        framework=None,
        model_id=model_id,
        model_version=MODEL_VERSION,
        image_scope=SCOPE,
        instance_type=instance_type
    )

    # Retrieve the model artifact S3 URI of pretrained machine learning models
    inference_model_uri = model_uris.retrieve(
        model_id=model_id,
        model_version=MODEL_VERSION,
        model_scope=SCOPE,
        region=region_name
    )

    model_docker_image = inference_image_uri

    model_bucket_name = inference_model_uri.split("/")[2]
    model_bucket_key = "/".join(inference_model_uri.split("/")[3:])

    return {
        "model_id": model_id, \
        "instance_type": instance_type, \
        "model_bucket_name":model_bucket_name, \
        "model_bucket_key": model_bucket_key, \
        "model_docker_image":model_docker_image, \
        "region_name":region_name
    }
