#!/usr/bin/env bash
# Fail fast in Helm section only
#------------------------------------------------------------------------------

###############################################################################
# Toggles
HELM_TEMPLATE_ENABLED=0      # 1 = run helm template loop
TERRAFORM_APPLY_ENABLED=1    # 1 = run terraform apply
UPDATE_KUBECONFIG_ENABLED=1  # 1 = update kubeconfig at the end

# Alias for the EKS context that kubectl will use
KUBE_ALIAS="gen3"

# Absolute path to the directory where this script is launched
script_dir="$(pwd)"
outputs_dir="${script_dir}/outputs"
charts_dir="${script_dir}/charts"
###############################################################################

#--------------------------------------------------------------------
# Helm dry-run templates ➜ ./outputs/<chart>.yaml
#--------------------------------------------------------------------
if [[ "$HELM_TEMPLATE_ENABLED" -eq 1 ]]; then
  (
    # Only this subshell exits on the first error
    set -e

    # Ensure outputs directory exists **before** we write into it
    mkdir -p "${outputs_dir}/templates"

    # Iterate over chart folders; the glob must not be quoted
    for folder in "${charts_dir}"/*; do
      [[ -d "$folder" ]] || continue            # skip if nothing matches
      chart_name="$(basename "$folder")"
      helm template "${chart_name}" "${folder}" \
        > "${outputs_dir}/templates/${chart_name}.yaml"
    done
  )

  # Prompt with 5-minute timeout
  printf "Read Helm templates in outputs folder
  Press Enter to continue 
  (or automatically proceed in 5 minutes)…"
  if ! read -r -t 300; then
    echo        # newline after timeout
    echo "Timeout reached — proceeding automatically."
  fi
fi

#--------------------------------------------------------------------
# Terraform init ➜ plan ➜ JSON plan file
#--------------------------------------------------------------------
mkdir -p "${outputs_dir}/tfplan"

terraform init
terraform plan \
  -out="${outputs_dir}/tfplan/tfplan.bin" \
  -var-file="${script_dir}/secrets.tfvars"

terraform show -json "${outputs_dir}/tfplan/tfplan.bin" \
  | jq . > "${outputs_dir}/tfplan/tfplan.json"

#--------------------------------------------------------------------
# Optional terraform apply ➜ JSON outputs
#--------------------------------------------------------------------
if [[ "$TERRAFORM_APPLY_ENABLED" -eq 1 ]]; then
  terraform apply "${outputs_dir}/tfplan/tfplan.bin"
  terraform output -json \
    | jq . > "${outputs_dir}/outputs.json"
fi

#--------------------------------------------------------------------
# Optional kubeconfig update
#--------------------------------------------------------------------
if [[ "$UPDATE_KUBECONFIG_ENABLED" -eq 1 ]]; then
  aws eks update-kubeconfig \
    --name  "$(terraform output -raw eks_cluster_name)" \
    --alias "${KUBE_ALIAS}" \
    --profile "$(terraform output -raw aws_profile)"

  kubectl config use-context "${KUBE_ALIAS}"
  kubectl get pods --all-namespaces
fi

# helm get manifest ack-ec2-controller-ec2-chart --namespace ack-system > ack-ec2-controller.yaml

# helm get manifest ack-s3-controller-s3-chart --namespace ack-system > ack-s3-controller.yaml
