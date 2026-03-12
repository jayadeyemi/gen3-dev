#!/usr/bin/env bash
###############################################################################
# lib-logging.sh — Shared logging helpers for gen3-dev scripts
#
# Source this file at the top of every script:
#   source "$(dirname "$0")/lib-logging.sh"
#
# Mirrors the logging conventions used in gen3-kro's container-init.sh.
###############################################################################

# ANSI colours (disabled when stdout is not a tty)
if [[ -t 1 ]]; then
  _CLR_RST='\033[0m'
  _CLR_GRN='\033[0;32m'
  _CLR_YLW='\033[0;33m'
  _CLR_RED='\033[0;31m'
  _CLR_BLU='\033[0;34m'
  _CLR_CYN='\033[0;36m'
else
  _CLR_RST='' _CLR_GRN='' _CLR_YLW='' _CLR_RED='' _CLR_BLU='' _CLR_CYN=''
fi

log_info()    { echo -e "${_CLR_BLU}  ℹ${_CLR_RST} $*"; }
log_success() { echo -e "${_CLR_GRN}  ✓${_CLR_RST} $*"; }
log_warn()    { echo -e "${_CLR_YLW}  ⚠${_CLR_RST} $*" >&2; }
log_error()   { echo -e "${_CLR_RED}  ✗${_CLR_RST} $*" >&2; }
log_stage()   { echo -e "\n${_CLR_CYN}>>> [$1]${_CLR_RST} $2"; }
log_banner()  {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  $*"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# wait_for_pods <namespace> [timeout_seconds]
# Waits for all pods in a namespace to reach Ready state.
wait_for_pods() {
  local ns="$1"
  local timeout="${2:-300}"
  log_info "Waiting for pods in namespace '$ns' (timeout: ${timeout}s)..."
  if kubectl wait --for=condition=Ready pods --all -n "$ns" --timeout="${timeout}s" 2>/dev/null; then
    log_success "All pods in '$ns' are Ready"
    return 0
  else
    log_warn "Some pods in '$ns' are not Ready after ${timeout}s"
    kubectl get pods -n "$ns" --no-headers 2>/dev/null || true
    return 1
  fi
}

# helm_install <release> <chart> <namespace> <version> [extra_args...]
# Wrapper around helm upgrade --install with common flags.
helm_install() {
  local release="$1" chart="$2" ns="$3" version="$4"
  shift 4
  log_info "Installing Helm release: $release (chart: $chart, version: $version, namespace: $ns)"
  helm upgrade --install "$release" "$chart" \
    --namespace "$ns" \
    --create-namespace \
    --version "$version" \
    --wait \
    --timeout 5m \
    "$@"
  log_success "Helm release '$release' installed"
}
