from ray.serve.llm import LLMConfig, build_openai_app
import os
llm_config = LLMConfig(
    model_loading_config=dict(
        model_id="my-llama-3.1-8b",
        model_source="unsloth/Meta-Llama-3.1-8B-Instruct",
    ),
    accelerator_type="A10G",
    deployment_config=dict(
        autoscaling_config=dict(
            min_replicas=1,
            max_replicas=4,
        )
    ),
    engine_kwargs=dict(
        max_model_len=8192,
        tensor_parallel_size=4,
    ),
)

app = build_openai_app({"llm_configs": [llm_config]})
