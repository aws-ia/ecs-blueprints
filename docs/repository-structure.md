# Repository structure

This page defines where code lives today, where it is heading, and the rules for adding
new blueprints. The goal driving every rule is the repository's purpose: a user should be
able to pick an example, apply it once, and adapt it in their own environment quickly.

## Target structure

```
terraform/
  patterns/          Self-contained blueprints: own VPC, cluster, and workload.
                     One `terraform apply`, one `terraform destroy`. The primary catalog.
  fargate-examples/  Shared-cluster examples that depend on the sibling core-infra root.
                     This catalog shrinks as examples convert to patterns/.
  ec2-examples/      EC2-capacity workloads (GPU/Neuron ML, self-managed ASGs). Also
                     shared-cluster; converts the same way over time.
  cicd-examples/     Pipeline and remote-state topologies.
  modules/           Reusable modules (CI/CD building blocks). Add a module only when it
                     provides real composition value beyond upstream registry modules.
cdk/
  examples/          Startable CDK apps only — every directory here is a valid entry point.
  components/        Shared constructs used by multiple examples (not deployable alone).
application-code/    Sample applications the blueprints deploy.
docs/                Cross-cutting documentation (this page, authentication, migrations,
                     the example contract).
```

## Rules for new content

1. **New Terraform blueprints go in `patterns/` and must be self-contained**: create your
   own VPC and cluster from upstream registry modules, accept a `name` variable so two
   copies can coexist in one account and Region, use a unique default VPC CIDR, and pass
   the README contract in [example-contract.md](./example-contract.md).
2. **New CDK examples go in `cdk/examples/<name>/`** with their private stacks under
   `lib/`. Constructs shared by several examples belong in `cdk/components/`. Supporting
   stacks used by a single example belong in that example's `lib/`, not a shared folder.
3. **Do not add new dependencies on `core-infra`.** The `core-infra` roots remain as an
   intentional "shared cluster, many services" topology reference — a pattern in their own
   right — not as a prerequisite for anything new.

## Migration state and history

The repository is converting shared-cluster examples to self-contained patterns
incrementally, following the same reasoning as the EKS Blueprints v5 redesign: patterns
are copy-paste teaching artifacts, so each one should be complete, tested, and deployable
on its own even at the cost of some duplicated module invocation.

Already converted (now in `terraform/patterns/`): `lb-service`, `backend-service`,
`graviton`, `sqs-dynamic-target-tracking`, plus the feature patterns built self-contained
from the start (`express-mode`, `native-deployment`, `managed-instances`,
`service-connect`, `ipv6-only`). The old `fargate-examples` paths for converted examples
contain README stubs pointing to the new location, so existing links and workshop
references keep resolving.

Still shared-cluster: `prometheus`, `queue-processing`, `vpc-endpoints`, `backstage`, and
the `ec2-examples` catalog. Convert these opportunistically — when an example needs
substantive work anyway, convert it in the same change.

## Verification

Static checks run in CI for every catalog (`.github/workflows/ci.yaml`): Terraform
fmt/validate, CDK tests and synth, application tests, Docker builds, and the README
contract (`scripts/ci/docs.sh`). Deployability of representative patterns is proven by
the scheduled deploy test (`.github/workflows/deploy-test.yaml`), which applies, smoke
tests, and destroys real infrastructure in a sandbox account via
`scripts/ci/deploy-test.sh`.
