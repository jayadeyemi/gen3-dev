#!/usr/bin/env bash
MODE="single"  # switch to eks
managed_OS="ubuntu" # Linux distribution ID "debian","amzn"

# Global values
AWS_REGION="us-east-1"
CLUSTER_NAME="my-cluster"

# Helm installation
# HELM_VERSION="3.8.0"

ACK_SYSTEM_NAMESPACE="ack-system"

# Release versions per controller
declare -A RELEASE_VERSIONS
RELEASE_VERSIONS=(
    [s3]="1.0.28"
    [ec2]="1.0.20"
    [vpc]="1.0.16"
    [rds]="1.0.25"
)
# Services to deploy
SERVICES=(
    "s3"
    "ec2"
    "vpc"
    "rds"
)



MANIFESTS_DIR="../../manifests" # Folder where CRs like ack-s3-bucket.yaml exist

environment="test"
REPO_URL="https://github.com/jayadeyemi/gen3_test.git"

# env/config.env
ACK_NAMESPACE="ack‑system"




CONTROLLERS="s3 ec2 rds dynamodb sqs sns lambda"
# ecr_public_repo login
username
password
chartVersion
# Reconcile intervals (seconds)
S3_SYNC=300
EC2_SYNC=500

# Git
PROJECT_REPO="https://github.com/jayadeyemi/gen3_test.git"
