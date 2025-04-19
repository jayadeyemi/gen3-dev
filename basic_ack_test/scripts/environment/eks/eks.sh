source "$(dirname "$0")/functions.sh"
install_controller "$SERVICE" "$RELEASE_VERSION" "$ACK_SYSTEM_NAMESPACE" "$AWS_REGION"
iam_permissions "$SERVICE" "$AWS_REGION" "$EKS_CLUSTER_NAME" "$ACK_SYSTEM_NAMESPACE"
