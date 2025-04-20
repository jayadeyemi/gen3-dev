#!/usr/bin/env bash
# deploy-ack-on-eks.sh
# Fully automated script to deploy ACK service controllers on EKS
# set -euo pipefail
# # -------------------------
# # STEP 1: Create EKS Cluster
# # -------------------------
# eksctl create cluster \
#   --name $EKS_CLUSTER_NAME \
#   --region $AWS_REGION \
#   --with-oidc \
#   --managed

# # -------------------------
# # STEP 2: Configure kubectl
# # -------------------------
# aws eks update-kubeconfig --region $AWS_REGION --name $EKS_CLUSTER_NAME

# # -------------------------
# # STEP 3: Install Helm (if needed)
# # -------------------------
# if ! command -v helm &>/dev/null; then
#   curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
#   chmod +x get_helm.sh && ./get_helm.sh
# fi


# -------------------------
# STEP 4: Deploy Each ACK Controller
# -------------------------
deploy_ack_controller() {
  local SERVICE=$1
  local ACK_K8S_SERVICE_ACCOUNT_NAME="ack-$SERVICE-controller"

#   echo "Creating namespace and service account for $SERVICE"
#   kubectl create namespace $ACK_SYSTEM_NAMESPACE || true
#   kubectl create serviceaccount $ACK_K8S_SERVICE_ACCOUNT_NAME -n $ACK_SYSTEM_NAMESPACE || true

#   echo "Setting up IAM role and policy for $SERVICE"
#   AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
#   OIDC_PROVIDER=$(aws eks describe-cluster --name $EKS_CLUSTER_NAME --region $AWS_REGION \
#     --query "cluster.identity.oidc.issuer" --output text | sed -e "s/^https:\/\///")

#   TRUST_RELATIONSHIP=$(cat <<EOF
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Effect": "Allow",
#       "Principal": {
#         "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/${OIDC_PROVIDER}"
#       },
#       "Action": "sts:AssumeRoleWithWebIdentity",
#       "Condition": {
#         "StringEquals": {
#           "${OIDC_PROVIDER}:sub": "system:serviceaccount:${ACK_SYSTEM_NAMESPACE}:${ACK_K8S_SERVICE_ACCOUNT_NAME}"
#         }
#       }
#     }
#   ]
# }
# EOF
# )

#   echo "$TRUST_RELATIONSHIP" > trust-${SERVICE}.json
#   ACK_CONTROLLER_IAM_ROLE="ack-${SERVICE}-controller"

#   aws iam create-role \
#     --role-name "$ACK_CONTROLLER_IAM_ROLE" \
#     --assume-role-policy-document file://trust-${SERVICE}.json \
#     --description "IRSA role for ACK $SERVICE controller"

#   BASE_URL="https://raw.githubusercontent.com/aws-controllers-k8s/${SERVICE}-controller/main/config/iam"

#   wget -qO- ${BASE_URL}/recommended-policy-arn | while read -r POLICY_ARN; do
#     aws iam attach-role-policy --role-name "$ACK_CONTROLLER_IAM_ROLE" --policy-arn "$POLICY_ARN"
#   done

#   INLINE_POLICY=$(wget -qO- ${BASE_URL}/recommended-inline-policy)
#   if [[ -n "$INLINE_POLICY" ]]; then
#     aws iam put-role-policy \
#       --role-name "$ACK_CONTROLLER_IAM_ROLE" \
#       --policy-name "ack-inline-policy" \
#       --policy-document "$INLINE_POLICY"
#   fi

#   ACK_CONTROLLER_IAM_ROLE_ARN=$(aws iam get-role --role-name $ACK_CONTROLLER_IAM_ROLE --query Role.Arn --output text)

  kubectl annotate serviceaccount -n $ACK_SYSTEM_NAMESPACE $ACK_K8S_SERVICE_ACCOUNT_NAME \
    "eks.amazonaws.com/role-arn=$ACK_CONTROLLER_IAM_ROLE_ARN" --overwrite

  aws ecr-public get-login-password --region $AWS_REGION | \
    helm registry login --username AWS --password-stdin public.ecr.aws

  helm upgrade --install ack-$SERVICE-controller oci://public.ecr.aws/aws-controllers-k8s/${SERVICE}-chart \
    --version=$RELEASE_VERSION \
    --namespace $ACK_SYSTEM_NAMESPACE \
    --set aws.region=$AWS_REGION

  echo "✅ ACK controller for $SERVICE deployed."

  # Deploy manifest for this service
  if [[ -f "$MANIFESTS_DIR/ack-${SERVICE}.yaml" ]]; then
    echo "Applying manifest: ack-${SERVICE}.yaml"
    kubectl apply -f "$MANIFESTS_DIR/ack-${SERVICE}.yaml"
  else
    echo "⚠️  Manifest ack-${SERVICE}.yaml not found, skipping resource deployment"
  fi
}

# Deploy all or select services
for SERVICE in "${SERVICES[@]}"; do
  deploy_ack_controller "$SERVICE"
done

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


# -------------------------
# STEP 5: Verify
# -------------------------
kubectl get pods -n $ACK_SYSTEM_NAMESPACE

# -------------------------
# STEP 6: Cleanup Function (Manual)
# -------------------------
cleanup_ack() {
  for SERVICE in "${SERVICES[@]}"; do
    helm uninstall ack-$SERVICE-controller -n $ACK_SYSTEM_NAMESPACE || true
    aws iam delete-role --role-name "ack-${SERVICE}-controller" || true
  done
  kubectl delete namespace $ACK_SYSTEM_NAMESPACE || true
}

echo "✅ All requested ACK controllers deployed. Use 'cleanup_ack' to uninstall."
