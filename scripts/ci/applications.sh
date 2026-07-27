#!/usr/bin/env bash
set -euo pipefail

python -m compileall -q \
  application-code \
  terraform/patterns/native-deployment/hooks \
  tests/application
python -m unittest discover -s tests/application -v

npm ci --prefix application-code/ecsdemo-nodejs
npm audit --omit=dev --audit-level=high --prefix application-code/ecsdemo-nodejs
npm test --prefix application-code/ecsdemo-nodejs

npm ci --prefix application-code/nodejs-demoapp/src
npm audit --omit=dev --audit-level=high --prefix application-code/nodejs-demoapp/src
npm test --prefix application-code/nodejs-demoapp/src
