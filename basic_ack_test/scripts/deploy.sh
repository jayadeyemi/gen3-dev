#!/bin/bash
set -e

# 1) Label nodes (replace with your actual node names or variables)
kubectl label node <node-name-1> role=s3
kubectl label node <node-name-2> role=vpc

# 2) Apply ACK custom resources
echo "Applying S3 Bucket manifest..."
kubectl apply -f ack-s3-bucket.yaml

echo "Applying VPC manifest..."
kubectl apply -f ack-vpc.yaml
