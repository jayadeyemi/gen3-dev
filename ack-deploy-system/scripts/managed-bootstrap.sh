# Usage: managed-bootstrap.sh --oidc-only <service-name>
if [[ "${1:-}" == "--oidc-only" ]]; then
    svc=$2
    # Read config
    bucket=$(yq e '.oidc.bucket' "$SCRIPT_DIR/values.yaml")
    AWS_REGION=$(yq e '.aws.region' "$SCRIPT_DIR/values.yaml")

    # use common pattern to generate/upload JWKS & provider
    $SCRIPT_DIR/etc/jwks.sh 
    # 2)check if s3 bucket exists
    if ! aws s3api head-bucket --bucket "${bucket}" 2>/dev/null; then
        echo "S3 bucket ${bucket} does not exist. Creating it..."
        aws s3api create-bucket \
            --bucket "${bucket}" \
            --region "${AWS_REGION}" \
            --create-bucket-configuration LocationConstraint="${AWS_REGION}"
    fi
    # Ensure OIDC bucket exists and upload JWKS
    aws s3api create-bucket \
        --bucket "$bucket" \
        --region "$AWS_REGION" \
        --create-bucket-configuration LocationConstraint="$AWS_REGION" \
        || true
    aws s3 cp "$jwks_file" "s3://${bucket}/.well-known/${jwks_file}"

    # Compute thumbprint
    thumbprint=$(echo | openssl s_client -servername s3.amazonaws.com -connect s3.amazonaws.com:443 2>/dev/null \
        | openssl x509 -fingerprint -noout \
        | sed 's/.*=//;s/://g')

    # Register OIDC provider in IAM if not present
    aws iam create-open-id-connect-provider \
        --url "https://${bucket}.s3.amazonaws.com" \
        --thumbprint-list "$thumbprint" \
        --client-id-list sts.amazonaws.com \
        || true

    # Export OIDC_HOST for downstream IRSA
    export OIDC_HOST="${bucket}.s3.amazonaws.com"
    exit 0
fi



# rename os to DISTRO
if [[ $1 == "--install-kubernetes" ]]; then
    os=$2
fi

if [[ "$os" == "--linux" ]]; then
DISTRO="linux"
elif [[ "$os" == "--amzn" ]]; then
DISTRO="amzn"
elif [[ "$os" == "--debian" ]]; then
DISTRO="debian"
else
    exit 1
fi


if [[ "$DISTRO" == "amzn" ]]; then
sudo yum update -y
sudo amazon-linux-extras install docker -y
sudo systemctl enable --now docker
sudo yum install -y kubelet kubeadm kubectl
elif [[ "$DISTRO" == "debian" ]]; then
echo "Installing Kubernetes on Debian"
sudo apt-get update -y
sudo apt-get install -y containerd 
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
sudo systemctl enable --now containerd
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | \
sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | \
sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable --now kubelet

sudo swapoff -a
sudo sed -i.bak '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
sudo modprobe br_netfilter
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward                = 1
EOF
sudo sysctl --system

LOCAL_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4 || echo "127.0.0.1")
sudo kubeadm init --pod-network-cidr=192.168.0.0/16 \
--upload-certs \
--control-plane-endpoint "${LOCAL_IP}:6443"

mkdir -p "~/.kube"
sudo cp /etc/kubernetes/admin.conf "~/.kube/config"
sudo chown "$(id -u):$(id -g)" "~/.kube/config"

kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true

log INFO "Single-node Kubernetes setup complete"

else
    echo "Unsupported distro: $os"
    exit 1
  fi
