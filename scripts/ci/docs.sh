#!/usr/bin/env bash
set -euo pipefail

status=0

for catalog in \
  terraform/patterns \
  terraform/fargate-examples \
  terraform/ec2-examples \
  terraform/cicd-examples \
  cdk/examples; do
  for root in "${catalog}"/*; do
    [[ -d "${root}" ]] || continue
    if find "${root}" -maxdepth 1 -type f \
      \( -name "*.tf" -o -name "app.py" -o -name "cdk.json" \) \
      -print -quit | grep -q . && [[ ! -f "${root}/README.md" ]]; then
      echo "${root}: missing README.md"
      status=1
    fi
  done
done

while IFS= read -r readme; do
  # Redirect stubs (directories with no deployable code) are exempt from the contract.
  root="$(dirname "${readme}")"
  find "${root}" -maxdepth 1 -type f \
    \( -name "*.tf" -o -name "app.py" -o -name "cdk.json" \) \
    -print -quit | grep -q . || continue
  for heading in Cost Quotas Validation Cleanup; do
    if ! grep -Eq "^## ${heading}$" "${readme}"; then
      echo "${readme}: missing '## ${heading}'"
      status=1
    fi
  done
done < <(
  find terraform/patterns terraform/fargate-examples \
    terraform/ec2-examples terraform/cicd-examples cdk/examples \
    -mindepth 2 -maxdepth 2 -type f -name README.md | sort
)

exit "${status}"
