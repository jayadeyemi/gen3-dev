---
applyTo: "argocd/**"
---

# ArgoCD & Component Stack Instructions

These rules apply when editing ArgoCD configuration, Helm charts,
or adding new components to the local stack.

## Sync-Wave Ordering

Components must be installed in dependency order. The wave numbers
match gen3-kro's `argocd/addons/csoc/addons.yaml`:

| Wave | Component | Why this order |
|------|-----------|---------------|
| -30 | KRO controller | Must register CRDs before any RGDs |
| 1 | ACK controllers (×7) | Need KRO running, talk to real AWS |
| 5 | ArgoCD | Follows ACK for uniform ordering |
| 10 | ResourceGraphDefinitions | Applied last, after all controllers ready |

## Bootstrap Model (Simplified)

gen3-kro uses a **3-layer ApplicationSet** bootstrap:
1. Terraform creates ArgoCD + bootstrap Application
2. Bootstrap Application creates region-specific ApplicationSets
3. ApplicationSets render addons from `addons.yaml`

gen3-dev **does not** replicate this. Instead:
- `kind-local-test.sh install` calls `helm upgrade --install` directly
- `argocd/bootstrap/local-addons.yaml` is a **reference document** only,
  showing what the ArgoCD equivalent would look like
- `argocd/addons/local/addons.yaml` documents the full component stack

When adding a new component:
1. Add its install step to `kind-local-test.sh` → `stage_install()`
2. Document it in `argocd/addons/local/addons.yaml`
3. Follow the sync-wave ordering above

## Helm Chart Conventions

RGD templates live under:
```
argocd/charts/resource-groups/templates/<name>-rg.yaml
```

The `Chart.yaml` and `values.yaml` are kept for structural parity with
gen3-kro. KRO handles parameterization via the RGD schema spec, not
Helm values.

## ACK Controller Configuration

Each ACK controller is Helm-installed with:
```yaml
aws:
  region: "us-east-1"
```

No `endpoint_url` override — controllers talk directly to real AWS APIs.
Credentials are injected via K8s Secret `ack-aws-credentials` created
from the mounted `~/.aws/credentials` file (MFA assumed-role).

Run `kind-local-test.sh inject-creds` after renewing credentials.

## Adding New ACK Controllers

If a new ACK controller is needed:
1. Add the Helm install to `stage_install()` in `kind-local-test.sh`
2. Use the same pattern: `oci://public.ecr.aws/aws-controllers-k8s/<svc>-chart`
3. Set `aws.region` (no endpoint_url)
4. Update the ACK controller table in `.github/copilot-instructions.md`
5. Document in `argocd/addons/local/addons.yaml`
