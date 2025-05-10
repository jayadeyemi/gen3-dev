
# # install dependencies
# apt-get update && \
#     apt-get install -y --no-install-recommends \
#       curl wget gnupg lsb-release git make vim nano less entr \
#       ca-certificates socat conntrack iptables docker.io && \
#     rm -rf /var/lib/apt/lists/*

# # install kubectl
# curl -fsSL https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl \
#       -o /usr/local/bin/kubectl && \
#     chmod +x /usr/local/bin/kubectl

# # install helm
# curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

# # install kind
# [ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.27.0/kind-linux-amd64
# chmod +x ./kind
# sudo mv ./kind /usr/local/bin/kind

# create a kind cluster
kind create cluster --name gen3-dev --config values/kind-config.yaml

# install ingress-nginx
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller  --timeout=90s

# install gen3
helm repo add gen3 http://helm.gen3.org
helm repo update
helm upgrade --install gen3 gen3/gen3 -f ./values/values.yaml
helm dependency build aws/acks
kubectl create namespace ack-controllers --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace ack-network --dry-run=client -o yaml | kubectl apply -f -
# install ack-controllers
helm upgrade --install aws aws/acks --debug --dry-run 
# install ack-network
helm upgrade --install aws aws/acks --namespace ack-controllers