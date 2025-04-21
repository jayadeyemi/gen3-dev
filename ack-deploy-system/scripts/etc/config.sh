# Load cluster name (eks mode)
CLUSTER_NAME=$(yq e '.cluster.name' "$SCRIPT_DIR/values.yaml")
# Precompute AWS_ACCOUNT_ID
AWS_ACCOUNT_ID=$(yq e '.aws.accountId' "$SCRIPT_DIR/values.yaml")