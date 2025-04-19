# Install the AWS Controllers for Kubernetes
#!/usr/bin/env bash
# scripts/install-controllers.sh
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"
source "$(dirname "$0")/lib/iam.sh"

aws ecr-public get-login-password --region us-east-1 \
  | helm registry login --username AWS --password-stdin public.ecr.aws

IFS=',' read -ra svc_arr <<< "$CONTROLLERS"
for svc in "${svc_arr[@]}"; do
  log INFO "Installing ACK chart for $svc"
  create_irsa "$svc"
  helm upgrade --install "ack-$svc" \
     "oci://public.ecr.aws/aws-controllers-k8s/${svc}-chart" \
     --namespace "$ACK_NAMESPACE" --create-namespace \
     --version "$chartVersion" \
     --set aws.region="$AWS_REGION"
done