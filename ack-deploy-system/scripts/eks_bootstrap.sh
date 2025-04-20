  if ! aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" &>/dev/null; then
    log INFO "Creating new EKS cluster..."
    eksctl create cluster \
      --name "$CLUSTER_NAME" \
      --region "$AWS_REGION" \
      --nodes 2 \
      --with-oidc \
      --managed
  else
    log INFO "EKS cluster already exists"
  fi