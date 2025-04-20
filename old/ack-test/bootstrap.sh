#!/usr/bin/env bash
set -euo pipefail

# 0.  export deployment mode
export MODE=eks
# export MODE=single

# 1.  Set up environment variables
source "$(dirname "$0")/scripts/lib/common.sh"
source "$(dirname "$0")/scripts/etc/release.sh"
source "$(dirname "$0")/scripts/etc/config.sh"

# 1.  Create Kubernetes cluster
source $SCRIPT_DIR/scripts/cluster-bootstrap.sh
# 2.  Install ACK controllers (+ IRSA roles)
source $SCRIPT_DIR/scripts/install-controllers.sh
# 3.  Deploy all manifest files
kubectl apply -f ./manifests/ack-system.yaml

# 3.  Deploy demo Bucket + VPC custom resources
helm upgrade --install $ROOT_DIR/ack-infra ./helm -f helm/values.yaml