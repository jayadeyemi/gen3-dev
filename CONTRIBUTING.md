# Contributing to gen3-dev

## Development Workflow

### 1. Create or Update a ResourceGraphDefinition

RGD files live in `argocd/charts/resource-groups/templates/` with the
naming convention `<name>-rg.yaml`.

Follow the conventions in `.github/instructions/kro-rgd.instructions.md`:
- Use KRO DSL for schema fields
- Include ACK annotations on all AWS resources
- Use `readyWhen` + `includeWhen` patterns from gen3-kro

### 2. Create a Test Instance

Add a matching instance manifest in `tests/local/`:
```yaml
apiVersion: v1alpha1
kind: <YourCRDKind>
metadata:
  name: test-1
  namespace: gen3-dev-test
spec:
  name: my-test
  # ... fields matching the RGD schema
```

### 3. Update validate-rgd.sh

Add a new test function in `tests/local/validate-rgd.sh` and wire it
into the `main()` case statement.

### 4. Test Locally

```bash
# Full pipeline: create cluster → install stack → inject creds → run tests
bash scripts/kind-local-test.sh create install inject-creds test

# Or step-by-step:
bash scripts/kind-local-test.sh create install inject-creds
./tests/local/validate-rgd.sh smoke
./tests/local/validate-rgd.sh storage

# Tear down when done
bash scripts/kind-local-test.sh destroy
```

### 5. Keep gen3-kro Parity

When creating resources, match gen3-kro's conventions:
- Same ACK annotation pattern (`services.k8s.aws/region`, etc.)
- Same tag structure (`Name`, `Environment`, `ManagedBy`, `Project`)
- Same sync-wave ordering
- Same Helm chart layout under `argocd/charts/`

## Shell Script Standards

- `set -euo pipefail` at the top of every script
- Source `scripts/lib-logging.sh` — never use raw `echo` for status output
- Quote all variables: `"${var}"` not `$var`
- Use the flag-based orchestration pattern (see `kind-local-test.sh`)

## Adding a New ACK Controller

1. Add Helm install to `scripts/kind-local-test.sh` → `stage_install()`
2. Use `oci://public.ecr.aws/aws-controllers-k8s/<svc>-chart`
3. Set `aws.region` (no `endpoint_url` — controllers talk to real AWS)
4. Update the ACK controller table in `.github/copilot-instructions.md`
5. Document in `argocd/addons/local/addons.yaml`

## AWS Credentials

ACK controllers use a K8s Secret (`ack-aws-credentials`) in the
`ack-system` namespace, created from the mounted `~/.aws/credentials`.
After renewing MFA credentials on the host, run:

```bash
bash scripts/kind-local-test.sh inject-creds
```

## Commit Guidelines

- Keep commits atomic (one logical change per commit)
- **Never commit AWS account IDs, secrets, or credentials**
- Reference gen3-kro issue numbers where applicable
- Test with `validate-rgd.sh all` before pushing
