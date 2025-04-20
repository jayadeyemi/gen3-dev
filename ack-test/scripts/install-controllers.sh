#!/usr/bin/env bash
=set -euo pipefail
if [[ $MODE != "eks" ]]; then
    # Create a namespace for the ACK service account
    kubectl create namespace "$ACK_SYSTEM_NAMESPACE" || true

    # Create a service account for the ACK controller
    kubectl create serviceaccount "$ACK_K8S_SERVICE_ACCOUNT_NAME" -n "$ACK_SYSTEM_NAMESPACE" || true
fi
source "$SCRIPT_DIR/scripts/lib/ssh-keygen.sh"
source "$SCRIPT_DIR/scripts/lib/key-store.sh"
OIDC_PROVIDER=$OIDC_BUCKET


source "$SCRIPT_DIR/scripts/oidc.sh"
source "$SCRIPT_DIR/scripts/irsa.sh"


IFS=',' read -ra svc_arr <<< "$CONTROLLERS"
for svc in "${svc_arr[@]}"; do
    export ACK_K8S_SERVICE_ACCOUNT_NAME="ack-$SERVICE-controller"
    log INFO "Installing ACK chart for $svc"
    create_iam_oidc  "SERVICE" "$CLUSTER_NAME" "$AWS_REGION"
    create_irsa "$svc"
  
    aws ecr-public get-login-password --region us-east-1 \
    | helm registry login --username AWS --password-stdin public.ecr.aws

    helm upgrade --install "ack-$svc" \
        "oci://public.ecr.aws/aws-controllers-k8s/${svc}-chart" \
        --namespace "$ACK_NAMESPACE" --create-namespace \
        --version "$chartVersion" \
        --set aws.region="$AWS_REGION"
done

