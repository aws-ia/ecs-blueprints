# AWS authentication

Use short-lived credentials for local development and CI. Do not create IAM users or place
long-lived access keys in `~/.aws/credentials` for these examples.

For workforce access, configure AWS IAM Identity Center with AWS CLI v2:

```bash
aws configure sso --profile ecs-blueprints
aws sso login --profile ecs-blueprints
export AWS_PROFILE=ecs-blueprints
export AWS_REGION=us-west-2
aws sts get-caller-identity
```

For automated workflows, use GitHub Actions OpenID Connect to assume a scoped IAM role.
Repository secrets should not contain AWS access keys.

Run examples in a dedicated sandbox account. Start with permissions sufficient for the
specific blueprint and review the Terraform plan or CDK diff before granting additional
access.
