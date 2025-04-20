# Use lightweight Ubuntu base
FROM ubuntu:25.04

# Prevent interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    unzip \
    git \
    jq \
    ca-certificates \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Install AWS CLI
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && ./aws/install && \
    rm -rf awscliv2.zip aws

# Clone the GitHub repository
RUN git clone --depth 1 https://github.com/jayadeyemi/gen3_test && \
    rm -rf gen3_test/.git

# Set working directory
WORKDIR /ack-deploy-system

# Make entrypoint script executable
RUN chmod +x ./deploy.sh

# Set entrypoint
ENTRYPOINT ["./ack-deploy-system/deploy.sh"]
