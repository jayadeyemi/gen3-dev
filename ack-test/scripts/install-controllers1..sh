#!/usr/bin/env bash
=set -euo pipefail
if [[ $MODE != "eks" ]]; then
    source "$SCRIPT_DIR/scripts/eks-bootstrap.sh"
else
    source "$SCRIPT_DIR/scripts/managed-bootstrap.sh"
fi

# pseudocode sketch
for svc in $(yq e '.controllers[].name' values-eks.yaml); do
  SA="ack-${svc}-controller"
  ROLE="${SA}-irsa"
  HOST=$(yq e '.oidc.host' values-eks.yaml)
  # generate trust-policy-${svc}.json using $HOST, $SA, $ROLE
  # aws iam create-role/associate-iam-oidc-provider...
done
