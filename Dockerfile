# gen3-dev Local CSOC Container
# Variant of gen3-kro's Dockerfile — adds Kind binary for the local
# Kubernetes cluster. Includes AWS CLI v2 for real AWS API access.
# Does NOT include Terraform / Terragrunt (infrastructure is managed
# via KRO + ACK, not Terraform).
#
# Ubuntu 24.04 with tools for Kubernetes, Helm, ArgoCD, AWS CLI, and KRO.

# UV_VERSION must be defined before the first FROM when used in COPY --from below.
ARG UV_VERSION=0.10.2

# Pull uv/uvx binaries in a separate stage to avoid ARG expansion in --from.
FROM ghcr.io/astral-sh/uv:${UV_VERSION} AS uvbin

FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

ENV DEBIAN_FRONTEND=noninteractive

# Set versions for consistency (match gen3-kro where applicable)
ARG KUBECTL_VERSION=1.35.1
ARG HELM_VERSION=3.16.1
ARG AWS_CLI_VERSION=2.32.0
ARG YQ_VERSION=4.44.3
ARG KIND_VERSION=0.27.0

# Base dependencies (includes Node/NPM for npx + Python for uvx-based tools).
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    wget \
    jq \
    unzip \
    git \
    git-lfs \
    bubblewrap \
    uidmap \
    socat \
    tini \
    bash-completion \
    vim \
    less \
    groff \
    python3 \
    python3-pip \
    python3-venv \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

# Sanity check: Node >= 18 required for Context7 MCP
RUN node --version && npm --version && npx --version

# Install yq (YAML processor) — same version as gen3-kro
RUN curl -fsSL --retry 3 --retry-delay 2 \
    -o /usr/local/bin/yq \
    "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64" \
    && chmod +x /usr/local/bin/yq \
    && yq --version

# Install uv + uvx
COPY --from=uvbin /uv /uvx /usr/local/bin/
RUN chmod +x /usr/local/bin/uv /usr/local/bin/uvx \
    && uv --version \
    && uvx --version

# Install kubectl — same version as gen3-kro
RUN set -eux; \
    curl -fsSL --retry 3 --retry-delay 2 \
      "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
      -o /usr/local/bin/kubectl; \
    chmod +x /usr/local/bin/kubectl; \
    kubectl version --client

# Install AWS CLI v2 — required for credential validation and ACK credential injection
RUN set -eux; \
    curl -fsSL --retry 3 --retry-delay 2 \
      "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWS_CLI_VERSION}.zip" \
      -o /tmp/awscli.zip; \
    unzip -q /tmp/awscli.zip -d /tmp; \
    /tmp/aws/install; \
    rm -rf /tmp/awscli.zip /tmp/aws; \
    aws --version

# Install Helm — same version as gen3-kro
RUN set -eux; \
    curl -fsSL --retry 3 --retry-delay 2 \
      "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" \
      -o /tmp/helm.tar.gz; \
    tar -xzf /tmp/helm.tar.gz -C /tmp; \
    mv /tmp/linux-amd64/helm /usr/local/bin/helm; \
    rm -rf /tmp/helm.tar.gz /tmp/linux-amd64; \
    chmod +x /usr/local/bin/helm; \
    helm version

# Install Kind — local Kubernetes cluster tool
RUN set -eux; \
    curl -fsSL --retry 3 --retry-delay 2 \
      -o /usr/local/bin/kind \
      "https://kind.sigs.k8s.io/dl/v${KIND_VERSION}/kind-linux-amd64"; \
    chmod +x /usr/local/bin/kind; \
    kind version

# Install k9s (Kubernetes CLI UI)
RUN set -eux; \
    curl -fsSL --retry 3 --retry-delay 2 \
      "https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_amd64.tar.gz" \
      | tar xz -C /tmp; \
    mv /tmp/k9s /usr/local/bin/k9s; \
    chmod +x /usr/local/bin/k9s; \
    k9s version

# Install ArgoCD CLI
RUN set -eux; \
    curl -fsSL --retry 3 --retry-delay 2 \
      -o /usr/local/bin/argocd \
      "https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64"; \
    chmod +x /usr/local/bin/argocd; \
    argocd version --client

# Install kustomize — same version as gen3-kro
RUN set -eux; \
    KUSTOMIZE_VERSION="5.7.1"; \
    curl -fsSL --retry 3 --retry-delay 2 \
      "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize/v${KUSTOMIZE_VERSION}/kustomize_v${KUSTOMIZE_VERSION}_linux_amd64.tar.gz" \
      | tar xz -C /tmp; \
    mv /tmp/kustomize /usr/local/bin/kustomize; \
    chmod +x /usr/local/bin/kustomize; \
    kustomize version

# Bash completion for kubectl and helm
RUN kubectl completion bash > /etc/bash_completion.d/kubectl \
    && helm completion bash > /etc/bash_completion.d/helm

# Workspace directory
RUN mkdir -p /workspaces && chown -R vscode:vscode /workspaces

# Use tini as PID 1 so foreground processes receive signals correctly.
ENTRYPOINT ["/usr/bin/tini", "--"]

# Use vscode user by default (important for devcontainers)
USER vscode
WORKDIR /workspaces

# Aliases and startup banner (mirrors gen3-kro conventions)
RUN echo 'alias k=kubectl' >> /home/vscode/.bashrc \
    && echo 'alias kctx="kubectl config use-context"' >> /home/vscode/.bashrc \
    && echo 'complete -F __start_kubectl k' >> /home/vscode/.bashrc \
    && echo 'export PS1="\[\033[01;32m\]\u@gen3-dev\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "' >> /home/vscode/.bashrc \
    && echo '' >> /home/vscode/.bashrc \
    && echo '# Display installed tools on terminal start' >> /home/vscode/.bashrc \
    && echo 'echo "=== gen3-dev Local CSOC Tools ==="' >> /home/vscode/.bashrc \
    && echo 'echo "kubectl:    $(kubectl version --client --short 2>/dev/null || kubectl version --client 2>/dev/null | head -n1)"' >> /home/vscode/.bashrc \
    && echo 'echo "Helm:       $(helm version --short)"' >> /home/vscode/.bashrc \
    && echo 'echo "Kind:       $(kind version)"' >> /home/vscode/.bashrc \
    && echo 'echo "ArgoCD CLI: $(argocd version --client --short 2>/dev/null || argocd version --client 2>/dev/null | head -n1)"' >> /home/vscode/.bashrc \
    && echo 'echo "AWS CLI:    $(aws --version 2>/dev/null | cut -d/ -f2 | cut -d" " -f1)"' >> /home/vscode/.bashrc \
    && echo 'echo "yq:         $(yq --version)"' >> /home/vscode/.bashrc \
    && echo 'echo "uv:         $(uv --version)"' >> /home/vscode/.bashrc \
    && echo 'echo "Node:       $(node --version)"' >> /home/vscode/.bashrc \
    && echo 'echo "==============================="' >> /home/vscode/.bashrc \
    && echo 'echo ""' >> /home/vscode/.bashrc \
    && echo '# Source local env if available' >> /home/vscode/.bashrc \
    && echo '# Source local env if available' >> /home/vscode/.bashrc \
    && echo '[[ -f "${REPO_ROOT}/config/local.env" ]] && source "${REPO_ROOT}/config/local.env"' >> /home/vscode/.bashrc \
    && echo '# Display credential tier on login' >> /home/vscode/.bashrc \
    && echo 'if [[ -f /home/vscode/.aws/credentials ]]; then echo "AWS Profile: ${AWS_PROFILE:-csoc}"; else echo "⚠ No AWS credentials — run mfa-session.sh on HOST"; fi' >> /home/vscode/.bashrc

CMD ["/bin/bash"]
