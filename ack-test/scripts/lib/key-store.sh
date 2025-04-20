OIDC_URL="https://s3.$AWS_REGION.amazonaws.com/$OIDC_BUCKET/.well-known/jwks.json"

# 4) Create (or ensure) S3 bucket & upload JWKS
aws s3api create-bucket \
  --bucket "$OIDC_BUCKET" \
  --region "$AWS_REGION" \
  --create-bucket-configuration LocationConstraint="$AWS_REGION" \
  || true
aws s3 cp jwks.json "s3://${OIDC_BUCKET}/.well-known/jwks.json"

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