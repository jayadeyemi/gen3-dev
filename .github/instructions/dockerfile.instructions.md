---
applyTo: "Dockerfile,.devcontainer/**"
---

# Dockerfile & DevContainer Instructions

These rules apply when editing the container image or DevContainer config.

## Base Image

Ubuntu 24.04 via `mcr.microsoft.com/devcontainers/base:ubuntu-24.04`.
Same base as gen3-kro's Dockerfile.

## Tool Version Pinning

All tool versions are pinned as `ARG` directives for reproducibility:

| Tool | ARG Name | Version |
|------|----------|---------|
| kubectl | `KUBECTL_VERSION` | 1.35.1 |
| Helm | `HELM_VERSION` | 3.16.1 |
| yq | `YQ_VERSION` | 4.44.3 |
| Kind | `KIND_VERSION` | 0.27.0 |
| AWS CLI | `AWS_CLI_VERSION` | 2.32.0 |
| uv | `UV_VERSION` | 0.10.2 |

When bumping versions, update the corresponding ARG and verify downstream
compatibility.

## Differences from gen3-kro's Dockerfile

| Added in gen3-dev | Removed vs gen3-kro |
|-------------------|---------------------|
| Kind binary | Terraform |
| | Terragrunt |

gen3-dev includes AWS CLI v2 for credential validation and direct AWS API
access. Kind binary is added for local cluster management.

## Security Posture

- `--security-opt=no-new-privileges` in devcontainer.json
- User: `vscode` (non-root)
- `overrideCommand: false` — container runs its own entrypoint

## Mount Conventions

The DevContainer mounts:
- `~/.aws/eks-devcontainer` → `/home/vscode/.aws` (read-write) — MFA-assumed-role credentials
- `~/.gen3-dev` → `/home/vscode/.gen3-dev` (read-write) — dedicated kubeconfig

It does **NOT** mount `~/.kube` — gen3-dev uses a dedicated kubeconfig
path to avoid conflicts with the host's kubeconfig.

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `KIND_CLUSTER_NAME` | `gen3-local` — used by kind-local-test.sh |
| `KUBECONFIG` | `/home/vscode/.gen3-dev/kubeconfig` |
| `AWS_PROFILE` | `csoc` — MFA-assumed-role profile |
| `KUBE_EDITOR` | `code --wait` |

## Bash Startup

The Dockerfile appends to `/home/vscode/.bashrc`:
- Sources `config/local.env` if it exists
- Sets `PS1` to show `gen3-dev` identity
- Adds Helm/kubectl bash completions

## Port Forwarding

| Port | Service | Access |
|------|---------|--------|
| 8080 | ArgoCD UI (port-forward) | `http://localhost:8080` |
| 30080 | ArgoCD NodePort | `http://localhost:30080` |
