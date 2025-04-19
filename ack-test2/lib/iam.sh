create_irsa() {
  local service="$1"

  local sa="ack-${service}-controller"
  local role="ack-${service}-irsa"
  local policy_url="https://raw.githubusercontent.com/aws-controllers-k8s/${service}-controller/main/config/iam"

  eksctl utils associate-iam-oidc-provider \
    --cluster "$CLUSTER_NAME" --region "$AWS_REGION" --approve >/dev/null

  if ! aws iam get-role --role-name "$role" >/dev/null 2>&1; then
    log INFO  "Creating role $role"
    eksctl create iamserviceaccount \
      --name  "$sa" \
      --namespace "$ACK_NAMESPACE" \
      --cluster "$CLUSTER_NAME" \
      --attach-policy-arn "$(curl -s ${policy_url}/recommended-policy-arn)" \
      --approve --override-existing-serviceaccounts --region "$AWS_REGION"
  fi
}
