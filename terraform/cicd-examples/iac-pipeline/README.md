# Terraform IaC pipeline

This example creates a CodeCommit source repository, CodePipeline workflow, and scoped
CodeBuild deployment projects for the development core-infrastructure and load-balanced
service roots. It expects the bootstrap bucket from `../external-state-bucket`.

```shell
state_bucket="$(
  aws ssm get-parameter \
    --name terraform_state_bucket \
    --query 'Parameter.Value' \
    --output text
)"

terraform init
terraform plan -var="s3_bucket=${state_bucket}"
terraform apply -var="s3_bucket=${state_bucket}"
```

Push the expected Terraform roots and buildspec files to the generated repository's
`main` branch only after reviewing the deployment-role policies.

## Cost

This example creates CodePipeline, CodeBuild projects, an artifact path in S3, IAM roles,
and a CodeCommit repository. Pipeline executions and build minutes incur charges, and
deployed workload stages create additional infrastructure.

## Quotas

Confirm CodePipeline, CodeBuild, IAM role, CodeCommit, and S3 quotas. CodeCommit is not
available to new AWS customers; use an existing supported source connection where
necessary.

## Validation

Run `terraform fmt -check`, `terraform init`, `terraform validate`, and review
`terraform plan`. After apply, verify each role policy is limited to the intended
deployment resources, then run a controlled source revision and inspect both CodeBuild
logs and the resulting Terraform plans.

## Cleanup

Remove workloads created by pipeline stages before destroying this root. Then run
`terraform destroy -var="s3_bucket=${state_bucket}"`. Delete the bootstrap state bucket
only after all dependent states and artifact versions are no longer needed.
