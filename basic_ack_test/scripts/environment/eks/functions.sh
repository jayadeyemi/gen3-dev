
eks_install_controller(){
    local SERVICE=$1
    local RELEASE_VERSION=$2
    local ACK_SYSTEM_NAMESPACE=$3
    local AWS_REGION=$4
    local CHART_REPO="public.ecr.aws/aws-controllers-k8s/${SERVICE}-chart"
    aws ecr-public get-login-password --region us-east-1 | helm registry login --username AWS --password-stdin public.ecr.aws
    helm install --create-namespace -n $ACK_SYSTEM_NAMESPACE ack-$SERVICE-controller \
      oci://public.ecr.aws/aws-controllers-k8s/$SERVICE-chart --version=$RELEASE_VERSION --set=aws.region=$AWS_REGION
}

eks_iam_permissions(){
    local SERVICE=$1
    local AWS_REGION=$2
    local EKS_CLUSTER_NAME=$3
    local ACK_SYSTEM_NAMESPACE=$4
    local ACK_K8S_SERVICE_ACCOUNT_NAME=ack-$SERVICE-controller

    # Create IAM OIDC provider for the cluster
    source "$(dirname "$0")/iam/oidc.sh"
    source "$(dirname "$0")/iam/iam-role.sh"
    source "$(dirname "$0")/iam/iam-policy.sh"
}