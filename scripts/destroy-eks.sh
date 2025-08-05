#!/bin/bash
script_dir="$(pwd)"

terraform state rm 'module.gen3-commons.random_string.suffix' > /dev/null || true
# Terraform plan
terraform destroy -var-file="${script_dir}/secrets.tfvars" -auto-approve 
# -var-file="${script_dir}/terraform.tfvars" -auto-approve

# Remove the outputs directory if it exists
if [ -d "${script_dir}/outputs" ]; then
  rm "${script_dir}/outputs"
fi
