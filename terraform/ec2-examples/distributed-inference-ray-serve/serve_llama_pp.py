from ray.serve.llm import LLMConfig, build_openai_app


llm_config = LLMConfig(
    model_loading_config=dict(
        model_id="my-llama-3.1-8b",
        model_source="unsloth/Meta-Llama-3.1-8B-Instruct",
    ),
    accelerator_type="A10G",
    deployment_config=dict(
        autoscaling_config=dict(
            min_replicas=1,
            max_replicas=1,
        )
    ),
    engine_kwargs=dict(
        max_model_len=8192,
        tensor_parallel_size=4, # set to the number of GPUs per instance
        pipeline_parallel_size=3 # set to the number of instances
    ),
)

app = build_openai_app({"llm_configs": [llm_config]})
