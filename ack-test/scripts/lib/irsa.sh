create_irsa() {
    local SERVICE="$1"
    local ACK_SYSTEM_NAMESPACE="$2"
    local CLUSTER_NAME="$3"
    local AWS_REGION="$4"
    local ACK_K8S_SERVICE_ACCOUNT_NAME="ack-${SERVICE}-controller"
    local ACK_CONTROLLER_IAM_ROLE="ack-${SERVICE}-irsa"
    local POLICY_URL="https://raw.githubusercontent.com/aws-controllers-k8s/${SERVICE}-controller/main/config/iam"


    if [[ "$MODE" == "eks" ]]; then
        log INFO "[EKS MODE] Setting up IRSA for $SERVICE"

        AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
        OIDC_PROVIDER=$(aws eks describe-cluster --name $EKS_CLUSTER_NAME --region $AWS_REGION --query "cluster.identity.oidc.issuer" --output text | sed -e "s/^https:\/\///")

        $ROOT_DIR/scripts/trust-relationship.sh 
        

        echo "${TRUST_RELATIONSHIP}" > trust.json

        aws iam create-role \
            --role-name "$ACK_CONTROLLER_IAM_ROLE" \
            --assume-role-policy-document file://trust.json \
            --description "IRSA role for ACK $SERVICE conxtroller (self-hosted)"

        ACK_CONTROLLER_IAM_ROLE_ARN=$(aws iam get-role --role-name=$ACK_CONTROLLER_IAM_ROLE --query Role.Arn --output text)
        BASE_URL=https://raw.githubusercontent.com/aws-controllers-k8s/${SERVICE}-controller/main
        POLICY_ARN_URL=${BASE_URL}/config/iam/recommended-policy-arn
        POLICY_ARN_STRINGS="$(wget -qO- ${POLICY_ARN_URL})"

        INLINE_POLICY_URL=${BASE_URL}/config/iam/recommended-inline-policy
        INLINE_POLICY="$(wget -qO- ${INLINE_POLICY_URL})"

        while IFS= read -r POLICY_ARN; do
            echo -n "Attaching $POLICY_ARN ... "
            aws iam attach-role-policy \
                --role-name "${ACK_CONTROLLER_IAM_ROLE}" \
                --policy-arn "${POLICY_ARN}"
            echo "ok."
        done <<< "$POLICY_ARN_STRINGS"

        if [ ! -z "$INLINE_POLICY" ]; then
            echo -n "Putting inline policy ... "
            aws iam put-role-policy \
                --role-name "${ACK_CONTROLLER_IAM_ROLE}" \
                --policy-name "ack-recommended-policy" \
                --policy-document "$INLINE_POLICY"
            echo "ok."
        fi
        kubectl describe serviceaccount/$ACK_K8S_SERVICE_ACCOUNT_NAME -n $ACK_K8S_NAMESPACE
        export IRSA_ROLE_ARN=eks.amazonaws.com/role-arn=$ACK_CONTROLLER_IAM_ROLE_ARN
        kubectl annotate serviceaccount -n $ACK_K8S_NAMESPACE $ACK_K8S_SERVICE_ACCOUNT_NAME $IRSA_ROLE_ARN
        # Note the deployment name for ACK service controller from following command
        kubectl get deployments -n $ACK_K8S_NAMESPACE
        kubectl -n $ACK_K8S_NAMESPACE rollout restart deployment <ACK deployment name>

        kubectl get pods -n $ACK_K8S_NAMESPACE
        kubectl describe pod -n $ACK_K8S_NAMESPACE <NAME> | grep "^\s*AWS_"
    
    else

        ./ssh-keygen.sh
        ./key-store.sh
        kubectl create namespace $ACK_SYSTEM_NAMESPACE || true
        kubectl create serviceaccount $ACK_K8S_SERVICE_ACCOUNT_NAME -n $ACK_SYSTEM_NAMESPACE || true
        OIDC_PROVIDER=$OIDC_BUCKET
        $ROOT_DIR/scripts/trust-relationship.sh 
        

        echo "${TRUST_RELATIONSHIP}" > trust.json

        # 8) Create the IAM role with that trust policy
        aws iam create-role \
        --role-name "$IAM_ROLE_NAME" \
        --assume-role-policy-document file://trust-policy.json

        # Note the deployment name for ACK service controller from following command
        ACK_DEPLOYMENT_NAME=$(kubectl get deployments -n ${ACK_SYSTEM_NAMESPACE} --no-headers | grep "$SERVICE" | awk '{print $1}')
        kubectl -n ${ACK_SYSTEM_NAMESPACE} rollout restart deployment "$ACK_DEPLOYMENT_NAME"
    fi
}
