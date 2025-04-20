# Create an IAM OIDC identity provider for the EKS cluster
create_iam_oidc(){
    local SERVICE=$1
    local CLUSTER_NAME=$2
    local AWS_REGION=$3
    
    if [[ "$MODE" == "eks" ]]; then
        log INFO "[EKS MODE] Setting up IRSA for $SERVICE"

        # Ensure OIDC provider is associated
        if ! eksctl utils describe-stacks --cluster "$CLUSTER_NAME" --region "$AWS_REGION" | grep -q "OIDC"; then
        log INFO "Associating OIDC provider with cluster $CLUSTER_NAME"
        eksctl utils associate-iam-oidc-provider \
            --region "$AWS_REGION" \
            --cluster "$CLUSTER_NAME" \
            --approve >/dev/null
        fi
    else
        log INFO "[LOCAL MODE] Setting up IRSA for $SERVICE using self-hosted OIDC"
        OIDC_PROVIDER=$(oc get authentication cluster -ojson | jq -r .spec.serviceAccountIssuer | sed -e "s/^https:\/\///")
        export OIDC_PROVIDER
}