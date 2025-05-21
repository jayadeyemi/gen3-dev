#!/usr/bin/env bash
set -euxo pipefail
IFS=$'\n\t'
# 1. Create Kind clusters: csoc, dev, staging, prod
for cluster in csoc; do
  kind get clusters | grep -q "^gen3-${cluster}$" || \
  kind create cluster --name "gen3-${cluster}" --config "config/${cluster}/config.yaml"
  kubectl --context="kind-gen3-${cluster}" apply \
    -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
  kubectl --context="kind-gen3-${cluster}" create namespace test-namespace-${cluster} --dry-run=client -o yaml \
    | kubectl apply -f -
done

# 3. Add & update the Helm repos
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# 4. Build the Helm charts
helm dependency update charts/argocd
helm dependency build  charts/argocd
helm dependency update charts/ack-controllers
helm dependency build  charts/ack-controllers

kubectl get namespace -o name | grep ack-systems || \
  kubectl create namespace ack-systems
  
# 5. Install Argo CD Core
helm upgrade --install argocd charts/argocd \
  --namespace argocd \
  --create-namespace \
  -f charts/argocd/values.yaml

# 6. Update the Custom Resources for Argo CD
helm upgrade --install argocd-deploy charts/argocd-deploy \
  --namespace argocd \
  --create-namespace \
  -f charts/argocd-deploy/values.yaml

# 7) Expose the Argo CD server port, backgrounded
kubectl port-forward svc/argocd-server -n argocd 8080:443 \
  >/dev/null 2>&1 &

# Give it a moment to establish the tunnel
sleep 5

# 8) Log in to Argo CD
export ARGOCD_SERVER=localhost:8080
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)
argocd login $ARGOCD_SERVER \
  --username admin \
  --password $ARGOCD_PASSWORD \
  --insecure



# 9) Now add your Kind cluster
argocd cluster add kind-gen3-csoc \
  --name kind-gen3-csoc \
  --insecure \
  --in-cluster \
  --upsert \
  --label app=csoc \
  --label valuesDir=ack-controller \
  --label namespace=ack-controllers \
  --yes





