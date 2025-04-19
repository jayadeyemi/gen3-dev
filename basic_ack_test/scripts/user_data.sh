#!/bin/bash
set -euxo pipefail


# import environment variables
source "$(dirname "$0")/environment/data.env"
# Variables
APP_DIR="/opt/basic-ack-test"

# Update and install Git
sudo apt update -y && sudo apt install -y git || sudo yum install -y git

# Clone project
mkdir -p "$APP_DIR"
cd /opt
git clone "$REPO_URL"
cd "$APP_DIR"

# Make scripts executable
chmod +x scripts/*.sh

# Check if environment is not eks, install kubernetes with single node + containerd + helm
if [[ "$environment" != "eks" ]]; then
    source "$(dirname "$0")/environment/managed/setup-single-node.sh"
fi
# Step 3: Install ACK Helm charts for S3 and  other services
# list of services

# ECR Helm repo
# Install controller for each service
if [[ "$environment" == "eks" ]]; then
    for SERVICE in "${SERVICE_LIST[@]}"; do
        echo "Installing ACK $SERVICE controller"
        source "$(dirname "$0")/environment/eks/eks.sh"
    done
fi

# Step 5: Verify Verify that your service account exists 
kubectl describe serviceaccount/$ACK_K8S_SERVICE_ACCOUNT_NAME -n $ACK_K8S_NAMESPACE
# Restart ACK service controller deployment
kubectl get deployments -n $ACK_K8S_NAMESPACE
kubectl -n $ACK_K8S_NAMESPACE rollout restart deployment <ACK deployment name>

# Verify that the AWS_WEB_IDENTITY_TOKEN_FILE and AWS_ROLE_ARN environment variables exist for your Kubernetes pod
kubectl get pods -n $ACK_K8S_NAMESPACE
kubectl describe pod -n $ACK_K8S_NAMESPACE <NAME> | grep "^\s*AWS_"


