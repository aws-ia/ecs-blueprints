# Fargate examples (shared-cluster catalog)

This folder contains examples built on a shared ECS Fargate cluster: deploy
[core-infra](./core-infra/README.md) first, then any of the examples below into it. The
`core-infra` root is also useful on its own as a "shared cluster, many services" topology
reference.

Shared-cluster examples:

* [Backstage developer portal](./backstage/README.md)

Looking for `lb-service`, `backend-service`, `graviton`, `queue-processing`,
`sqs-dynamic-target-tracking`, `prometheus`, or `vpc-endpoints`? They are now
self-contained and live in [`terraform/patterns/`](../patterns/), the repository's primary
catalog. New contributions should be self-contained patterns — see the
[repository structure guide](../../docs/repository-structure.md).
