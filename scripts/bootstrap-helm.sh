#!/usr/bin/env bash
set -euo pipefail

# Ensure all dependencies are fetched
helm repo add argo https://argoproj.github.io/argo-helm
helm repo add aws-controllers oci://public.ecr.aws/aws-controllers-k8s/ack-chart
helm repo update

for chart in charts/argocd charts/ack-controllers charts/ack-infra charts/gen3-deploy; do
  helm dependency update "${chart}"
  helm dependency build "${chart}"
done

# Lint all charts
for chart in charts/argocd charts/ack-controllers charts/ack-infra charts/gen3-deploy; do
  helm lint "${chart}"
done
