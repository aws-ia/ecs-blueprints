#!/usr/bin/env bash
set -euo pipefail

terraform fmt -check -recursive terraform

while IFS= read -r versions_file; do
  directory=$(dirname "${versions_file}")
  data_dir=$(mktemp -d)
  echo "Validating ${directory}"
  TF_DATA_DIR="${data_dir}" terraform -chdir="${directory}" init \
    -backend=false -input=false -no-color
  TF_DATA_DIR="${data_dir}" terraform -chdir="${directory}" validate -no-color
  rm -rf "${data_dir}"
done < <(
  find terraform -type d -name .terraform -prune \
    -o -type f -name versions.tf -print | sort
)
