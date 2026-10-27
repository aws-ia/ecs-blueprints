# Blueprint documentation contract

Every blueprint README must explain the following operational concerns in addition to its
architecture and deployment steps.

## Cost

Identify the resources that dominate cost, whether the example is suitable for short-lived
evaluation, and any resources that continue billing while idle.

## Quotas

List the AWS service quotas or scarce capacity that commonly block deployment. Accelerated
compute examples must call out Region and instance availability.

## Validation

Provide static validation commands and at least one post-deployment functional check. A
successful `terraform apply` or `cdk deploy` is not by itself a functional check.

## Cleanup

Give the exact destroy command, note ordering constraints, and identify retained or
out-of-band resources that require separate deletion.

CI enforces these four second-level headings for every blueprint under the Terraform and CDK
example directories.
