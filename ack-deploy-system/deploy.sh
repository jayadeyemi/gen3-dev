#!/usr/bin/env bash
set -euo pipefail

export PS4='+${BASH_SOURCE}:${LINENO}: '
set -x

# Choose a path that’s writable both in-container and on your host:
LOGFILE="${MANAGED_BOOTSTRAP_LOG:-$(pwd)/bootstrap.log}"
exec > >(tee "${LOGFILE}") 2>&1

# ------------------------------------------------------

container=${container:-}
MODE=${MODE:-}
deployment_mode="${deployment_mode:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ------------------------------------------------------

if [[ -z "$MODE" ]]; then
    MODE=$(yq e '.mode' "$(dirname "${BASH_SOURCE[0]}")/values.yaml")
fi

if [[ -z "$deployment_mode" ]]; then
    deployment_mode=$(yq e '.deploymentType' "$(dirname "${BASH_SOURCE[0]}")/values.yaml")
fi

echo "Running in $deployment_mode mode"
echo "Running in $container mode"
echo "Running in $MODE mode"

if [[ "$deployment_mode" == "ec2" ]]; then
    source "$SCRIPT_DIR/../launcher.sh"
elif [[ "$deployment_mode" == "local" ]]; then
    # Check if running in a container
    if [[ $container != "docker" ]]; then
        source "$SCRIPT_DIR/../docker-build.sh"
    fi
fi

# Load shared scripts
source "$SCRIPT_DIR/scripts/etc/common.sh"
source "$SCRIPT_DIR/scripts/etc/config.sh"

# Mode‑specific bootstrap
case "$MODE" in
eks)    source "$SCRIPT_DIR/scripts/eks-bootstrap.sh"    ;;  
managed-linux) source "$SCRIPT_DIR/scripts/managed-bootstrap.sh" --install-kubernetes "--linux" ;; 
managed-debian) source "$SCRIPT_DIR/scripts/managed-bootstrap.sh" --install-kubernetes "--debian" ;;
managed-amzn) source "$SCRIPT_DIR/scripts/managed-bootstrap.sh" --install-kubernetes "--amzn" ;;
managed-ubuntu) source "$SCRIPT_DIR/scripts/managed-bootstrap.sh" --install-kubernetes "--ubuntu" ;;
*)      log ERROR "Unsupported MODE: $MODE"; exit 1 ;;  
esac

# Load globals
VALUES_FILE="$SCRIPT_DIR/values.yaml"
AWS_REGION=$(yq e '.aws.region'      "$VALUES_FILE")
ACK_NAMESPACE=$(yq e '.ackNamespace'  "$VALUES_FILE")
CHART_REPO_BASE=$(yq e '.chartRepoBase' "$VALUES_FILE")
ACK_IAM_BUCKET=$(yq e '.IAMBucket.name' "$VALUES_FILE")

# install helm
install_helm()

# Deploy each controller
mapfile -t SRVS < <(yq e '.controllers[].name' "$VALUES_FILE")

for svc in "${SRVS[@]}"; do
    # Extract per‑service values
    CHART_VERSION=$(yq e ".controllers[] | select(.name==\"$svc\") | .chartVersion" "$VALUES_FILE")
    REPLICAS=$(yq e ".controllers[] | select(.name==\"$svc\") | .replicaCount" "$VALUES_FILE")
    SA_CREATE=$(yq e ".controllers[] | select(.name==\"$svc\") | .serviceAccount.create" "$VALUES_FILE")
    SA_NAME=$(yq e ".controllers[] | select(.name==\"$svc\") | .serviceAccount.name" "$VALUES_FILE")
    ROLE_ARN=$(yq e ".controllers[] | select(.name==\"$svc\") | .serviceAccount.annotations.\"eks.amazonaws.com/role-arn\"" "$VALUES_FILE")
    IMG_REPO=$(yq e ".controllers[] | select(.name==\"$svc\") | .image.repository" "$VALUES_FILE")
    IMG_TAG=$(yq e ".controllers[] | select(.name==\"$svc\") | .image.tag" "$VALUES_FILE")
    CPU_REQ=$(yq e ".controllers[] | select(.name==\"$svc\") | .resources.requests.cpu" "$VALUES_FILE")
    MEM_REQ=$(yq e ".controllers[] | select(.name==\"$svc\") | .resources.requests.memory" "$VALUES_FILE")
    CPU_LIM=$(yq e ".controllers[] | select(.name==\"$svc\") | .resources.limits.cpu" "$VALUES_FILE")
    MEM_LIM=$(yq e ".controllers[] | select(.name==\"$svc\") | .resources.limits.memory" "$VALUES_FILE")

    log INFO "Bootstrapping IRSA for $svc..."
        create_iam_oidc "$svc" && create_irsa "$svc" "$SA_NAME"


    log INFO "Deploying ACK-$svc via Helm..."
    aws ecr-public get-login-password --region "$AWS_REGION" \
        | helm registry login --username AWS --password-stdin public.ecr.aws

    helm upgrade --install "ack-$svc" \
        "$CHART_REPO_BASE/$svc-chart" \
        --namespace "$ACK_NAMESPACE" --create-namespace \
        --version "$CHART_VERSION" \
        --set aws.region="$AWS_REGION" \
        --set replicaCount="$REPLICAS" \
        --set image.repository="$IMG_REPO" \
        --set image.tag="$IMG_TAG" \
        --set serviceAccount.create="$SA_CREATE" \
        --set serviceAccount.name="$SA_NAME" \
        --set serviceAccount.annotations.eks\.amazonaws\.com/role-arn="$ROLE_ARN" \
        --set resources.requests.cpu="$CPU_REQ" \
        --set resources.requests.memory="$MEM_REQ" \
        --set resources.limits.cpu="$CPU_LIM" \
        --set resources.limits.memory="$MEM_LIM"
done

# Apply AWS Resources via ACK CRs
log INFO "Applying AWS resource manifests"
kubectl apply -f "$RES_DIR/ack-s3-buckets.yaml"  -n "$ACK_NAMESPACE"
kubectl apply -f "$RES_DIR/ack-vpcs.yaml"       -n "$ACK_NAMESPACE"
kubectl apply -f "$RES_DIR/ack-ec2-instances.yaml" -n "$ACK_NAMESPACE"