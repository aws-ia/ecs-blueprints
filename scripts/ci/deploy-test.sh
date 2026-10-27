#!/usr/bin/env bash
#
# Deploy-test: prove an example actually deploys, serves traffic, and destroys
# cleanly in a real AWS account. This is the enforcement mechanism behind the
# repository's "clone and apply once" promise - validate/synth checks cannot
# catch runtime failures (image pulls, IAM at call time, health checks).
#
# Usage:
#   scripts/ci/deploy-test.sh <terraform-root> [url-output-name]
#
# Examples:
#   scripts/ci/deploy-test.sh terraform/patterns/lb-service application_url
#   scripts/ci/deploy-test.sh terraform/patterns/express-mode quick_start_url
#
# Requires AWS credentials for a DEDICATED SANDBOX account. Always destroys,
# even when apply or the smoke test fails.
set -euo pipefail

ROOT="${1:?usage: deploy-test.sh <terraform-root> [url-output-name]}"
URL_OUTPUT="${2:-application_url}"
HTTP_RETRIES="${DEPLOY_TEST_HTTP_RETRIES:-30}"
HTTP_INTERVAL_SECONDS="${DEPLOY_TEST_HTTP_INTERVAL:-20}"

if [[ ! -d "${ROOT}" ]]; then
  echo "error: ${ROOT} is not a directory" >&2
  exit 2
fi

aws sts get-caller-identity >/dev/null || {
  echo "error: no AWS credentials; deploy-test needs a sandbox account" >&2
  exit 2
}

cd "${ROOT}"

destroy() {
  echo "--- destroy ${ROOT}"
  terraform destroy -auto-approve -input=false || {
    echo "warning: first destroy failed; retrying once" >&2
    sleep 30
    terraform destroy -auto-approve -input=false
  }
}

STATUS=1
trap 'destroy; exit "${STATUS}"' EXIT

echo "--- init ${ROOT}"
terraform init -input=false

echo "--- apply ${ROOT}"
terraform apply -auto-approve -input=false

url="$(terraform output -raw "${URL_OUTPUT}" 2>/dev/null || true)"
if [[ -n "${url}" ]]; then
  echo "--- smoke test ${url}"
  ok=""
  for _ in $(seq 1 "${HTTP_RETRIES}"); do
    code="$(curl -s -o /dev/null -m 10 -w '%{http_code}' "${url}" || true)"
    if [[ "${code}" =~ ^2|^3 ]]; then
      echo "HTTP ${code} from ${url}"
      ok=1
      break
    fi
    echo "waiting for service (last HTTP code: ${code:-none})"
    sleep "${HTTP_INTERVAL_SECONDS}"
  done
  if [[ -z "${ok}" ]]; then
    echo "error: service never returned 2xx/3xx at ${url}" >&2
    exit 1
  fi
else
  echo "--- no '${URL_OUTPUT}' output; treating successful apply as the test"
fi

STATUS=0
