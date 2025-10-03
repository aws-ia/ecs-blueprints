# ECS machine learning distributed training

This solution blueprint creates the infrastructure needed to run GenAI inference using [vLLM](https://docs.vllm.ai/en/latest/index.html) with [AWS Neuron](https://awsdocs-neuron.readthedocs-hosted.com/en/latest/) and Inferentia 2 instances.  This solution is based on similar examples for running inference using vLLM on [EKS](https://aws.amazon.com/blogs/machine-learning/deploy-meta-llama-3-1-8b-on-aws-inferentia-using-amazon-eks-and-vllm/) and [EC2](https://aws.amazon.com/blogs/machine-learning/serving-llms-using-vllm-and-amazon-ec2-instances-with-aws-ai-chips/) using Inferentia-based instances.

By default, this blueprint deploys inf2.8xlarge instances optimized for GenAI inference workloads. The setup is tailored for running vLLM with pre-compiled Neuron-compatible models. You can modify the instance type and resource allocation by changing the variables in the Terraform configuration.

## Components

*	ECS Cluster:
    *	Uses an autoscaling group to provision inf2 instances for the ECS cluster.
    *	Allows dynamic scaling of GenAI workloads.
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
curl -X POST http://<ALB_DNS_NAME>:8000/v1/completions \
-H "Content-Type: application/json" \
-d '{
  "model": "meta-llama/Llama-3.2-1B",
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
  "model": "meta-llama/Llama-3.2-1B",
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

1. Destroy this blueprint

```shell
terraform destroy
```

1. Destroy core-infra resources

```shell
cd ../core-infra
terraform destroy

```

## Troubleshooting



## Support

Please open an issue for questions or unexpected behavior
