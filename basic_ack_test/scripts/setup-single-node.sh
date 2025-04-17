
#!/usr/bin/env bash
set -euo pipefail

# Combined post‑install “second half” for Amazon Linux 2 & Ubuntu 24.04

# 0. Detect distribution
source /etc/os-release
if [[ "$ID" == "amzn" || "$ID_LIKE" =~ rhel ]]; then
  DISTRO="amzn"
elif [[ "$ID" == "ubuntu" ]]; then
  DISTRO="ubuntu"
else
  echo "Unsupported distribution: $ID"
  exit 1
fi

#!/usr/bin/env bash
set -euo pipefail



# 1. Install container runtime & Kubernetes tools
if [[ "$DISTRO" == "amzn" ]]; then
  # Amazon Linux 2
  sudo yum update -y
  sudo amazon-linux-extras install docker -y
  sudo systemctl enable --now docker
  sudo yum install -y kubelet kubeadm kubectl

elif [[ "$DISTRO" == "ubuntu" ]]; then
  # Ubuntu
  sudo apt-get update -y
  sudo apt-get install -y containerd
  sudo mkdir -p /etc/containerd
  sudo containerd config default | sudo tee /etc/containerd/config.toml
  sudo systemctl enable --now containerd
  # apt-transport-https may be a dummy package; if so, you can skip that package
  sudo apt-get update
  sudo apt-get install -y apt-transport-https ca-certificates curl gpg
  # If the directory `/etc/apt/keyrings` does not exist, it should be created before the curl command, read the note below.
  sudo mkdir -p -m 755 /etc/apt/keyrings
  curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  # This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
  echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

  sudo apt-get update
  sudo apt-get install -y kubelet kubeadm kubectl
  sudo apt-mark hold kubelet kubeadm kubectl
  sudo systemctl enable --now kubelet

fi

# 2. (Amazon Linux 2 only) Set SELinux to permissive
if [[ "$DISTRO" == "amzn" ]]; then
  sudo setenforce 0
  sudo sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
fi

# 3. Disable swap (required by kubeadm)
sudo swapoff -a
sudo sed -i.bak '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# 4. Load kernel modules & configure sysctl for pod networking
sudo modprobe br_netfilter
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward                = 1
EOF
sudo sysctl --system

# 5. Initialize the control plane
LOCAL_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
sudo kubeadm init \
  --pod-network-cidr=192.168.0.0/16 \
  --upload-certs \
  --control-plane-endpoint "${LOCAL_IP}:6443"

# 6. Set up kubectl for the invoking user
mkdir -p "${HOME}/.kube"
sudo cp -i /etc/kubernetes/admin.conf "${HOME}/.kube/config"
sudo chown "$(id -u):$(id -g)" "${HOME}/.kube/config"

# 7. Deploy Calico CNI for pod networking
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

# 8. Allow workloads on the control plane (for single‑node clusters)
kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true

# 89 Print the join command for worker nodes
echo
echo "================================================================"
echo "Control plane is ready. On each worker node, run:"
kubeadm token create --print-join-command
echo "================================================================"
