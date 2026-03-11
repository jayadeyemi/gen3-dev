---
applyTo: "scripts/**"
---

# Shell Script Conventions

These rules apply when creating or editing scripts in `scripts/`.

## Error Handling

Every script must start with:
```bash
set -euo pipefail
```

## Logging

Source the shared logging library instead of raw echo:
```bash
source "${REPO_ROOT}/scripts/lib-logging.sh"
```

Available functions:
- `log_info "message"` — blue `[INFO]`
- `log_success "message"` — green `[OK]`
- `log_warn "message"` — yellow `[WARN]`
- `log_error "message"` — red `[ERROR]`
- `log_stage "message"` — bold cyan header
- `log_banner "message"` — full-width banner

## Flag-Based Orchestration

`kind-local-test.sh` uses positional flags (not getopts) to select stages.
This mirrors gen3-kro's `container-init.sh` pattern:

```bash
for arg in "$@"; do
  case "${arg}" in
    create)  FLAG_CREATE=true ;;
    install) FLAG_INSTALL=true ;;
    # ...
  esac
done
```

When adding new stages, follow this pattern — don't switch to getopts.

## Helm Install Pattern

Use the `helm_install` wrapper from `lib-logging.sh`:
```bash
helm_install <release> <chart_ref> <namespace> [extra_args...]
```

This wraps `helm upgrade --install --create-namespace --wait --timeout 5m`.

## kubectl Wait Pattern

Use the `wait_for_pods` wrapper:
```bash
wait_for_pods <namespace> [timeout]
```

This calls `kubectl wait --for=condition=Ready pod --all -n <ns>`.

## Variable Quoting

Always quote variables to prevent word splitting:
```bash
"${CLUSTER_NAME}"   # ✓
$CLUSTER_NAME        # ✗
```

## Script Paths

Use portable path resolution at the top of every script:
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
```
