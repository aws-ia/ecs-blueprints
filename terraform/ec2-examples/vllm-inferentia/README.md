# ECS Inference using vLLM with inf2

This solution blueprint creates the infrastructure to run models in multiple nueron cores using tensor parallelism within a single task with vLLM. By default, it uses one inf2.8xlarge instance.


## Components

*	ECS Cluster
*	ECS Service Definition:
    *	vLLM Service: Configured to serve requests for GenAI inference using vLLM.
*	Application Load Balancer:
    *	Exposes the vLLM inference service endpoint to clients.
    *	Configured with a target group and health checks for monitoring service availability.
*	CloudWatch Logs:
    *	Logs from ECS tasks and services are collected in CloudWatch for monitoring and debugging.


## Deployment

1. Deploy core-infra resources

```shell
cd ./terraform/ec2-examples/core-infra
terraform init
terraform apply -target=module.vpc -target=aws_service_discovery_private_dns_namespace.this
```

2. Deploy this blueprint

```shell
cd ../vllm-inferentia
terraform init
terraform apply
```

## Example: Running GenAI Inference

Once the cluster and services are deployed, you can use the load balancer DNS name (output during the deployment) to send requests to the vLLM service.


Send a POST request to the vLLM OpenAI-compatible endpoint:
```bash

ALB_DNS_NAME=$(terraform output -raw load_balancer_dns_name)

curl -X POST http://$ALB_DNS_NAME:8000/v1/completions \
-H "Content-Type: application/json" \
-d '{
  "model": "TinyLlama/TinyLlama-1.1B-Chat-v1.0",
  "prompt": "Write a short poem about technology",
  "max_tokens": 100,
  "temperature": 0.7
}'
```

Example Response:
```json
{
  "id": "cmpl-6ze...",
  "object": "text_completion",
  "created": 1680307267,
  "model": "TinyLlama/TinyLlama-1.1B-Chat-v1.0",
  "choices": [
    {
      "text": "\n\nTechnology, a wondrous art,\nA force that shapes the world's heart.\nIn circuits small and data vast,\nIt links the future to the past.",
      "index": 0,
      "logprobs": null,
      "finish_reason": "stop"
    }
  ]
}
```

## What do you do next?

Congratulations on successfully deploying your vLLM inference solution on ECS with AWS Inferentia! Here are some ideas to take your implementation to the next level:

1. Explore Frontend Integrations
	* Gradio: Use [Gradio](https://www.gradio.app/) to create an interactive web interface for your model, allowing users to test various prompts and visualize responses.
	* OpenWebUI: Deploy [OpenWebUI](https://github.com/open-webui/open-webui) as an additional frontend for your model, providing a user-friendly way to interact with the OpenAI-compatible endpoint.

2. Build Custom Python Applications
	*	Create Python scripts or applications that integrate your inference service to solve real-world problems:
	*	Automate customer support chatbots.
	*	Generate summaries, translations, or other natural language tasks.
	*	Build a personalized AI assistant tailored to your organizational needs.

3. Integrate with Existing Workflows
	*	Serverless Architectures: Use AWS Lambda or Step Functions to trigger and process model inference requests in response to specific events.
	*	Data Pipelines: Integrate the model into your data pipelines for real-time predictions or insights, such as tagging or categorizing documents automatically.
	*	CRM and ERP Systems: Embed the model into your enterprise systems to provide intelligent insights or streamline processes.

4. Optimize for Performance
	*	Experiment with different batch sizes and parallelization settings in vLLM to handle more concurrent requests or improve latency.
	*	Use Neuron monitoring tools to analyze and fine-tune the utilization of Inferentia chips for maximum efficiency.

5. Scale and Extend
	*	Add multi-model support by deploying multiple versions of your model (e.g., fine-tuned for specific tasks) and routing traffic dynamically using the ALB.
	*	Experiment with autoscaling policies to dynamically adjust the number of running tasks based on request volume.

6. Learn from Amazon’s Approach
	*	Discover how Amazon’s engineering team [scaled generative AI for Amazon Rufus](https://aws.amazon.com/blogs/machine-learning/scaling-rufus-the-amazon-generative-ai-powered-conversational-shopping-assistant-with-over-80000-aws-inferentia-and-aws-trainium-chips-for-prime-day/), powering conversational shopping experiences during Prime Day.
	*	Adapt lessons learned from their implementation to improve scalability, reliability, and cost-efficiency in your use case.

## Clean up

1. Stop ECS tasks and wait for the status to be propagated with ECS.

```shell
aws ecs update-service --service neuronx-vllm-service \
--desired-count 0 --cluster ecs-demo-vllm-inferentia \
--region us-west-2 --query 'service.serviceName'

sleep 30s
```

2. Destroy this blueprint

```shell
terraform destroy
```

3. Destroy core-infra resources

```shell
cd ../core-infra
terraform destroy

```

## Support

Please open an issue for questions or unexpected behavior
