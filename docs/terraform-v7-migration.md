# Terraform ECS module v7 migration

The Terraform examples use Terraform 1.5.7 or newer, AWS provider 6.x, and
`terraform-aws-modules/ecs` 7.5.0. A configuration that validates from empty state can
still replace resources when applied to state created by module v5. Upgrade one state at
a time and review both migration stages.

## Protect the current state

Stop automated applies and confirm that no other operator is changing the target state.
Use the existing backend and credentials. Store state and plan files in a private
temporary directory because both can contain secrets:

```bash
umask 077
migration_dir="$(mktemp -d "${TMPDIR:-/tmp}/ecs-v7.XXXXXX")"

terraform init
terraform state pull > "${migration_dir}/state-original.json"
terraform plan -refresh-only -out="${migration_dir}/refresh.tfplan"
terraform show "${migration_dir}/refresh.tfplan"
```

Resolve unexpected refresh drift before changing constraints. Keep the temporary
directory until workload validation is complete, then delete it securely according to
your workstation policy.

## Stage on the final v5 releases

Do not jump directly from an older v5 combination to v7. First constrain the AWS provider
to `5.100.0` and every `terraform-aws-modules/ecs` call to `5.12.1`, then initialize,
review, and apply that stage:

```bash
terraform init -upgrade
terraform validate
terraform plan -out="${migration_dir}/v5-stage.tfplan"
terraform show "${migration_dir}/v5-stage.tfplan"
terraform apply "${migration_dir}/v5-stage.tfplan"
terraform plan -detailed-exitcode
terraform state pull > "${migration_dir}/state-v5-stage.json"
```

The final command should return exit code 0. Resolve any v5-stage changes before starting
the provider 6/module 7 migration.

## Update the configuration

The provider 6/module 7 configuration requires:

- Terraform `>= 1.5.7`, AWS provider `~> 6.56`, and ECS module `7.5.0`.
- Container-definition fields in ECS API camel case, for example `portMappings`,
  `healthCheck`, and `readonlyRootFilesystem`.
- `security_group_rules` split into `security_group_ingress_rules` and
  `security_group_egress_rules`, using fields such as `referenced_security_group_id`,
  `cidr_ipv4`, and `ip_protocol`.
- `service_connect_configuration.service` changed from an object to a list of objects.
- Explicit `task_exec_ssm_param_arns` and `task_exec_secret_arns` for parameters and
  secrets read by the task execution role.
- `autoscaling_capacity_providers` renamed to `capacity_providers`, with each definition
  nested under `auto_scaling_group_provider`.
- Explicit `cluster_capacity_providers` for Fargate or externally managed providers.
- `ordered_placement_strategy` changed from a map to an ordered list.

For an existing cluster or service, set
`disable_v7_default_name_description = true` during migration. It prevents v7 naming and
description defaults from replacing existing IAM roles and security groups. The switch is
deprecated and should be removed only through a separately reviewed migration before
module v8. New roots must use v7 defaults and must not set it.

## Initialize before state surgery

After updating configuration and constraints, install provider 6 and module 7 before
changing any state addresses:

```bash
terraform init -upgrade
terraform validate
terraform state pull > "${migration_dir}/state-before-rule-imports.json"
```

Module v6 replaced `aws_security_group_rule` with separate
`aws_vpc_security_group_ingress_rule` and `aws_vpc_security_group_egress_rule` resources.
Terraform cannot move state between those resource types. Record each existing rule's AWS
ID from the old address:

```bash
terraform state show \
  'module.ecs_service.aws_security_group_rule.this["alb_ingress_3000"]'
```

For each rule, remove the old address and immediately import the same `sgr-...` object at
its configured v7 address:

```bash
terraform state rm \
  'module.ecs_service.aws_security_group_rule.this["alb_ingress_3000"]'
terraform import \
  'module.ecs_service.aws_vpc_security_group_ingress_rule.this["alb_3000"]' \
  sgr-0123456789abcdef0

terraform state rm \
  'module.ecs_service.aws_security_group_rule.this["egress_all"]'
terraform import \
  'module.ecs_service.aws_vpc_security_group_egress_rule.this["all"]' \
  sgr-0fedcba9876543210
```

`terraform state rm` is non-destructive to AWS: it removes only Terraform's address.
However, the security-group rule is unmanaged between that command and the successful
import. Do not continue to another rule when an import fails.

If an import fails, first correct the address or ID and retry it. If it cannot be
completed, restore the untouched state snapshot before running any plan or apply:

```bash
terraform state push -force "${migration_dir}/state-before-rule-imports.json"
```

Then restore the v5 configuration and dependency lock file, run `terraform init`, and
verify a no-op plan before retrying the migration. Because `state push -force` replaces
the complete state, use it only while automation is stopped and no concurrent state
changes have occurred.

Use the actual module address, map key, and rule ID from the target state. If the provider
cannot import an existing rule, schedule an approved maintenance window for a
delete-and-recreate change; never leave the rule silently unmanaged. The v6 task-role
policy also changes from inline to managed and is recreated because it cannot be moved or
imported.

## Review and apply

Save the final plan in the restricted temporary directory:

```bash
terraform plan -out="${migration_dir}/ecs-v7.tfplan"
terraform show -no-color "${migration_dir}/ecs-v7.tfplan" \
  > "${migration_dir}/ecs-v7-plan.txt"
```

Do not apply until:

- No cluster, service, task role, execution role, or service security group is replaced
  only because of a generated name or description.
- Existing security-group rules are imported rather than duplicated.
- Existing capacity providers remain associated with the cluster.
- Task definitions retain secrets, logging, ports, health checks, volumes, and Linux
  parameters after camel-case conversion.
- IAM changes do not restore wildcard access removed by security remediation.
- Provider changes do not alter unrelated resources.

Apply the saved plan, validate service health, and confirm a no-op plan:

```bash
terraform apply "${migration_dir}/ecs-v7.tfplan"
aws ecs wait services-stable --cluster <cluster-name> --services <service-name>
terraform plan -detailed-exitcode
```

Resume automation only after the final plan returns exit code 0.

## Reference validation

The `terraform/fargate-examples/core-infra` migration was tested by applying AWS provider
5.100.0 with ECS module 5.12.1, then upgrading the configuration and lock selections to
AWS provider 6.56.0 and ECS module 7.5.0. The upgrade plan had one new stabilization
resource, three in-place updates, and zero destroys or replacements. After apply,
`terraform plan -detailed-exitcode` returned exit code 0.

That result verifies the representative cluster state and the compatibility switch. It
does not replace a saved plan review for each state, especially service roots whose
security-group resource types change.
