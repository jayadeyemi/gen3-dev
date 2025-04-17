#!/usr/bin/env bash
set -e

if [[ -z "$NODE_S3" || -z "$NODE_VPC" ]]; then
  echo "Usage: NODE_S3=<node-1-name> NODE_VPC=<node-2-name> $0"
  exit 1
fi

kubectl label node "$NODE_S3" role=s3 --overwrite
kubectl label node "$NODE_VPC" role=vpc --overwrite
echo "Labeled $NODE_S3 as role=s3 and $NODE_VPC as role=vpc"
