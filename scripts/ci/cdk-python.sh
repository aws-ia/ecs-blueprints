#!/usr/bin/env bash
set -euo pipefail

export JSII_RUNTIME_PACKAGE_CACHE="${JSII_RUNTIME_PACKAGE_CACHE:-${RUNNER_TEMP:-/tmp}/jsii-runtime-package-cache}"
mkdir -p "${JSII_RUNTIME_PACKAGE_CACHE}"

python -m pip install --upgrade pip
python -m pip install -r cdk/requirements.txt -r cdk/requirements-dev.txt
python -m compileall -q \
  -x '(^|/)(node_modules|cdk\.out|\.venv)(/|$)' \
  cdk
PYTHONPATH=cdk:cdk/examples python -m pytest cdk/tests -q

for example in lb_service backend_service express_mode; do
  (
    cd "cdk/examples/${example}"
    cdk synth --quiet
  )
done
