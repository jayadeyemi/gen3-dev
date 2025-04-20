  # build trust policy
  cat > "$trust_file" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect":"Allow",
    "Principal":{"Federated":"arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/${OIDC_HOST}"},
    "Action":"sts:AssumeRoleWithWebIdentity",
    "Condition":{"StringEquals":{"${OIDC_HOST}:sub":"system:serviceaccount:${ACK_NAMESPACE}:${sa}"}}
  }]
}
EOF