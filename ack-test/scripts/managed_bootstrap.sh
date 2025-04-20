#!/usr/bin/env bash
set -euo pipefail

# ─── CONFIGURATION ────────────────────────────────────────────────────────────
SERVICE_ACCOUNT=${SERVICE_ACCOUNT:-ack-s3-controller}   # e.g. ack-s3-controller, ack-vpc-controller, etc.
IAM_ROLE_NAME=${IAM_ROLE_NAME:-${SERVICE_ACCOUNT}-irsa}
OIDC_BUCKET=${OIDC_BUCKET:-my-oidc-bucket}
AWS_REGION=${AWS_REGION:-us-east-1}
# File‐name prefixes
KEY_BASE="${SERVICE_ACCOUNT}-issuer"
JWKS_FILE="jwks-${SERVICE_ACCOUNT}.json"
TRUST_POLICY_FILE="trust-policy-${SERVICE_ACCOUNT}.json"
# ──────────────────────────────────────────────────────────────────────────────

# 1) Generate per-controller keypair
openssl genrsa -out "${KEY_BASE}.key" 2048
openssl rsa    -in "${KEY_BASE}.key" -pubout -out "${KEY_BASE}.pub"

# 2)check if s3 bucket exists
if ! aws s3api head-bucket --bucket "${OIDC_BUCKET}" 2>/dev/null; then
    echo "S3 bucket ${OIDC_BUCKET} does not exist. Creating it..."
    aws s3api create-bucket \
        --bucket "${OIDC_BUCKET}" \
        --region "${AWS_REGION}" \
        --create-bucket-configuration LocationConstraint="${AWS_REGION}"
fi

# 3) Construct JWKS JSON unique to this controller
source "$SCRIPT_DIR/scripts/lib/jwks.sh"

# 4) Upload JWKS to S3 under a controller‑specific path
aws s3 cp "${JWKS_FILE}" "s3://${OIDC_BUCKET}/.well-known/${JWKS_FILE}"

# 5) Build trust policy for this ServiceAccount
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

source "$SCRIPT_DIR/scripts/lib/trust-relationship.sh"
echo "${TRUST_RELATIONSHIP}" > "${TRUST_POLICY_FILE}"

# 5) Compute S3 HTTPS thumbprint for the root CA
THUMBPRINT=$(echo \
  | openssl s_client -connect s3.amazonaws.com:443 2>/dev/null \
  | openssl x509 -fingerprint -noout \
  | sed 's/.*=//;s/://g')

# 6) Register the OIDC provider in IAM
aws iam create-open-id-connect-provider \
  --url "$OIDC_URL" \
  --thumbprint-list "$THUMBPRINT" \
  --client-id-list sts.amazonaws.com

# 7) Create (or update) the IAM role
aws iam create-role \
  --role-name "${IAM_ROLE_NAME}" \
  --assume-role-policy-document file://"${TRUST_POLICY_FILE}" \
  || aws iam update-assume-role-policy \
       --role-name "${IAM_ROLE_NAME}" \
       --policy-document file://"${TRUST_POLICY_FILE}"

echo "Generated:"
echo " ${KEY_BASE}.key / ${KEY_BASE}.pub"
echo " ${JWKS_FILE} → s3://${OIDC_BUCKET}/.well-known/${JWKS_FILE}"
echo " ${TRUST_POLICY_FILE}"
echo " IAM Role arn:aws:iam::${AWS_ACCOUNT_ID}:role/${IAM_ROLE_NAME}"
