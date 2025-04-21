# ┌───────────────────────────────────────────────────────────────┐
# │                         Dockerfile                          │
# └───────────────────────────────────────────────────────────────┘

FROM ubuntu:25.04

# 1) Noninteractive frontend + common env vars
ENV DEBIAN_FRONTEND=noninteractive \
    PROJECT_ROOT=/workspace \
    GIT_REPO_URL=https://github.com/jayadeyemi/gen3_test.git \
    GIT_BRANCH=main

# 2) Install base tools
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      git bash curl unzip jq ca-certificates \
      coreutils vim less iputils-ping \
 && rm -rf /var/lib/apt/lists/*

# 3) AWS CLI v2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip \
 && unzip /tmp/awscliv2.zip -d /tmp \
 && /tmp/aws/install \
 && rm -rf /tmp/aws /tmp/awscliv2.zip

# 5) Helm
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 6) yq
RUN curl -Lo /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 \
 && chmod +x /usr/local/bin/yq


# 8) Clone your project
RUN git clone --branch ${GIT_BRANCH} ${GIT_REPO_URL} ${PROJECT_ROOT}

# 9) Make the deploy script executable
RUN chmod +x ${PROJECT_ROOT}/ack-deploy-system/deploy.sh


# # 10) Copy in the entrypoint helper
# COPY entrypoint.sh /usr/local/bin/entrypoint.sh
# RUN chmod +x /usr/local/bin/entrypoint.sh

# 11) Switch to project root
WORKDIR ${PROJECT_ROOT}

# 12) Kick off the entrypoint
# ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash"]
