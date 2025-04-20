#!/usr/bin/env bash
set -euo pipefail

# 0.  export deployment mode
export MODE=eks
# export MODE=single

# 1.  Create EKS cluster
./scripts/cluster-bootstrap.sh
# 2.  Install ACK controllers (+ IRSA roles)
./scripts/install‑controllers.sh

# 3.  Deploy all manifest files
kubectl apply -f ./manifests/ack-system.yaml

# 3.  Deploy demo Bucket + VPC custom resources
helm upgrade --install $ROOT_DIR/ack-infra ./helm -f helm/values.yaml