#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────────────────────
# CONFIGURATION (override via env‑vars as needed)
CLUSTER_NAME=${CLUSTER_NAME:-my-eks-cluster}
AWS_REGION=${AWS_REGION:-us-east-1}
NAMESPACE=${NAMESPACE:-ack-system}
SERVICE_ACCOUNT=${SERVICE_ACCOUNT:-ack-s3-controller}
IAM_ROLE_NAME=${IAM_ROLE_NAME:-${SERVICE_ACCOUNT}-irsa}
TRUST_POLICY_FILE="trust-policy-${SERVICE_ACCOUNT}.json"
# ──────────────────────────────────────────────────────────────────────────────

# 1) Ensure EKS OIDC provider is associated (idempotent)
eksctl utils associate-iam-oidc-provider \
  --cluster "$CLUSTER_NAME" \
  --region "$AWS_REGION" \
  --approve

# 2) Fetch the cluster’s OIDC issuer URL and host
OIDC_URL=$(aws eks describe-cluster \
  --name "$CLUSTER_NAME" \
  --region "$AWS_REGION" \
  --query "cluster.identity.oidc.issuer" \
  --output text)
OIDC_HOST=${OIDC_URL#https://}

# 3) Build trust‑policy JSON
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

source $SCRIPT_DIR/scripts/trust-relationship.sh

echo "${TRUST_RELATIONSHIP}" > "$TRUST_POLICY_FILE"

# 4) Create (or update) the IAM role using that trust policy
aws iam create-role \
  --role-name "$IAM_ROLE_NAME" \
  --assume-role-policy-document file://"$TRUST_POLICY_FILE" \
  || aws iam update-assume-role-policy \
       --role-name "$IAM_ROLE_NAME" \
       --policy-document file://"$TRUST_POLICY_FILE"

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
