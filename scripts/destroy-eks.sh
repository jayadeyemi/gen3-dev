#!/bin/bash
script_dir="$(pwd)"

terraform state rm 'module.gen3-commons.module.gen3-eks.random_string.suffix' > /dev/null || true
# Terraform plan
terraform destroy -auto-approve #-refresh=false

# Remove the outputs directory if it exists
if [ -d "${script_dir}/outputs" ]; then
  rm -rf "${script_dir}/outputs"
fi
