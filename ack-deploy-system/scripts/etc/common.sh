log() { level=$1; shift; echo "[$level] $*"; }

# Associates an OIDC provider if in EKS mode, or ensures local OIDC in managed mode
create_iam_oidc() {
  local svc=$1
  if [[ "$MODE" == "eks" ]]; then
    eksctl utils associate-iam-oidc-provider --cluster "$CLUSTER_NAME" --region "$AWS_REGION" --approve
    OIDC_URL=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" --query "cluster.identity.oidc.issuer" --output text)
    OIDC_HOST=${OIDC_URL#https://}
  else
    # generate/upload JWKS for local OIDC (managed mode)
    bash "$SCRIPT_DIR/scripts/managed-bootstrap.sh" --oidc-only "$svc"
  fi
}
install_helm() {
    if ! command -v helm &>/dev/null; then
        log INFO "Installing Helm..."
        curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
        chmod +x get_helm.sh && ./get_helm.sh
    fi
}

# install yq
install_yq() {
    if ! command -v yq &>/dev/null; then
        log INFO "Installing yq..."
        local yq_bin="yq_linux_amd64"
        # Download the latest Linux amd64 binary
        curl -sSL https://github.com/mikefarah/yq/releases/latest/download/"$yq_bin" -o /usr/local/bin/yq
        # Make it executable
        chmod +x /usr/local/bin/yq
    fi
}

# Creates or updates per‑controller IAM Role for IRSA
create_irsa() {
  local svc=$1
  local sa=$2
  sa=$(yq e ".controllers[] | select(.name==\"$svc\") | .serviceAccount.name" "$VALUES_FILE")
  local role_name="${sa}-irsa"
  local trust_file="$SCRIPT_DIR/outputs/${sa}-trust.json"
  mkdir -p "$(dirname "$trust_file")"
  source "$SCRIPT_DIR/scripts/etc/trust-policy.sh"
  echo "${TRUST_RELATIONSHIP}" > "$trust_file"

  aws iam create-role --role-name "$role_name" --assume-role-policy-document file://"$trust_file" \
    || aws iam update-assume-role-policy --role-name "$role_name" --policy-document file://"$trust_file"
}

