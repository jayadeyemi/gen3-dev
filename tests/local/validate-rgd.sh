#!/usr/bin/env bash
# =============================================================================
# validate-rgd.sh — End-to-end validation for KRO ResourceGraphDefinitions
# =============================================================================
#
# Applies an RGD, waits for CRD registration, applies an instance,
# polls child resources, and reports pass/fail.
#
# Usage:
#   ./tests/local/validate-rgd.sh smoke        # k8s-native smoke test
#   ./tests/local/validate-rgd.sh storage      # ACK → real AWS storage test
#   ./tests/local/validate-rgd.sh all          # both tiers
#
# Requirements:
#   - Kind cluster running (kind-local-test.sh create + install)
#   - kubectl configured for kind-gen3-local context
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source logging helpers
# shellcheck source=../../scripts/lib-logging.sh
source "${REPO_ROOT}/scripts/lib-logging.sh"

# ── Paths ──────────────────────────────────────────────────────────────────────
RGD_DIR="${REPO_ROOT}/argocd/charts/resource-groups/templates"
TEST_DIR="${REPO_ROOT}/tests/local"

# ── Timeouts ───────────────────────────────────────────────────────────────────
CRD_TIMEOUT=120          # seconds to wait for CRD registration
INSTANCE_TIMEOUT=180     # seconds to wait for instance readiness
POLL_INTERVAL=5          # seconds between polls

# ── Counters ───────────────────────────────────────────────────────────────────
PASS=0
FAIL=0
TESTS_RUN=0

# =============================================================================
# Helpers
# =============================================================================

wait_for_crd() {
  local crd_name="$1"
  local elapsed=0

  log_info "Waiting for CRD '${crd_name}' to be registered (timeout ${CRD_TIMEOUT}s)..."
  while ! kubectl get crd "${crd_name}" &>/dev/null; do
    sleep "${POLL_INTERVAL}"
    elapsed=$((elapsed + POLL_INTERVAL))
    if [[ ${elapsed} -ge ${CRD_TIMEOUT} ]]; then
      log_error "CRD '${crd_name}' not registered after ${CRD_TIMEOUT}s"
      return 1
    fi
  done
  log_success "CRD '${crd_name}' registered (${elapsed}s)"
}

wait_for_instance_ready() {
  local kind_lower="$1"
  local instance_name="$2"
  local instance_ns="${3:-default}"
  local elapsed=0

  log_info "Waiting for ${kind_lower}/${instance_name} to become ready (timeout ${INSTANCE_TIMEOUT}s)..."
  while true; do
    local state
    state=$(kubectl get "${kind_lower}" "${instance_name}" -n "${instance_ns}" \
      -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")

    if [[ "${state}" == "True" ]]; then
      log_success "${kind_lower}/${instance_name} is READY (${elapsed}s)"
      return 0
    fi

    sleep "${POLL_INTERVAL}"
    elapsed=$((elapsed + POLL_INTERVAL))
    if [[ ${elapsed} -ge ${INSTANCE_TIMEOUT} ]]; then
      log_warn "${kind_lower}/${instance_name} not ready after ${INSTANCE_TIMEOUT}s"
      log_info "Current status:"
      kubectl get "${kind_lower}" "${instance_name}" -n "${instance_ns}" -o yaml \
        | grep -A20 "^status:" || true
      return 1
    fi
  done
}

run_test() {
  local test_name="$1"
  local rgd_file="$2"
  local instance_file="$3"
  local crd_name="$4"
  local kind_lower="$5"
  local instance_name="$6"
  local instance_ns="${7:-default}"
  local child_checks=("${@:8}")  # remaining args are child resource checks

  TESTS_RUN=$((TESTS_RUN + 1))
  log_stage "TEST: ${test_name}"

  # Step 1: Apply RGD
  log_info "[1/5] Applying RGD: ${rgd_file}"
  if ! kubectl apply -f "${rgd_file}"; then
    log_error "Failed to apply RGD"
    FAIL=$((FAIL + 1))
    return 1
  fi

  # Step 2: Wait for CRD registration
  log_info "[2/5] Waiting for CRD registration..."
  if ! wait_for_crd "${crd_name}"; then
    FAIL=$((FAIL + 1))
    return 1
  fi

  # Step 3: Apply instance
  log_info "[3/5] Applying instance: ${instance_file}"
  if ! kubectl apply -f "${instance_file}"; then
    log_error "Failed to apply instance"
    FAIL=$((FAIL + 1))
    return 1
  fi

  # Step 4: Wait for instance readiness
  log_info "[4/5] Waiting for instance readiness..."
  if ! wait_for_instance_ready "${kind_lower}" "${instance_name}" "${instance_ns}"; then
    FAIL=$((FAIL + 1))
    return 1
  fi

  # Step 5: Verify child resources
  log_info "[5/5] Verifying child resources..."
  local child_ok=true
  for check in "${child_checks[@]}"; do
    # Each check is "resource_type/name/namespace" or "resource_type/name"
    IFS='/' read -r res_type res_name res_ns <<< "${check}"
    res_ns="${res_ns:-${instance_ns}}"

    if kubectl get "${res_type}" "${res_name}" -n "${res_ns}" &>/dev/null; then
      log_success "  ✓ ${res_type}/${res_name} exists in ${res_ns}"
    else
      log_error "  ✗ ${res_type}/${res_name} NOT found in ${res_ns}"
      child_ok=false
    fi
  done

  if ${child_ok}; then
    log_success "TEST PASSED: ${test_name}"
    PASS=$((PASS + 1))
  else
    log_error "TEST FAILED: ${test_name} (some child resources missing)"
    FAIL=$((FAIL + 1))
  fi

  return 0
}

cleanup_test() {
  local instance_file="$1"
  local rgd_file="$2"
  local test_name="$3"

  log_info "Cleaning up ${test_name}..."
  kubectl delete -f "${instance_file}" --ignore-not-found --wait=true --timeout=60s 2>/dev/null || true
  sleep 5
  kubectl delete -f "${rgd_file}" --ignore-not-found 2>/dev/null || true
}

# =============================================================================
# Test: K8s Smoke (Tier 1 — no ACK required)
# =============================================================================
test_smoke() {
  local rgd="${RGD_DIR}/k8s-smoke-rg.yaml"
  local instance="${TEST_DIR}/k8s-smoke-instance.yaml"

  run_test \
    "K8s Smoke Test (Tier 1)" \
    "${rgd}" \
    "${instance}" \
    "localsmoketests.v1alpha1" \
    "localsmoketest" \
    "smoke-1" \
    "default" \
    "namespace//smoke-test" \
    "configmap/smoke-app-config/smoke-test" \
    "deployment/smoke-app/smoke-test" \
    "service/smoke-app/smoke-test"

  cleanup_test "${instance}" "${rgd}" "K8s Smoke Test"
}

# =============================================================================
# Test: AWS Storage (Tier 2 — requires ACK + real AWS credentials)
# =============================================================================
test_storage() {
  local rgd="${RGD_DIR}/aws-storage-rg.yaml"
  local instance="${TEST_DIR}/aws-storage-instance.yaml"

  # Verify ACK CRDs are present before attempting
  local ack_ready=true
  for crd in buckets.s3.services.k8s.aws keys.kms.services.k8s.aws roles.iam.services.k8s.aws; do
    if ! kubectl get crd "${crd}" &>/dev/null; then
      log_warn "ACK CRD '${crd}' not found — is the ACK controller installed?"
      ack_ready=false
    fi
  done

  if ! ${ack_ready}; then
    log_error "Skipping AWS Storage test — ACK CRDs not available"
    log_info "Run 'kind-local-test.sh install' first to install ACK controllers"
    FAIL=$((FAIL + 1))
    TESTS_RUN=$((TESTS_RUN + 1))
    return 1
  fi

  # Verify AWS credentials are valid
  if ! aws sts get-caller-identity --profile "${AWS_PROFILE:-csoc}" &>/dev/null; then
    log_error "Skipping AWS Storage test — AWS credentials invalid or expired"
    log_info "Renew on HOST: bash scripts/mfa-session.sh <MFA_CODE>"
    log_info "Then: bash scripts/kind-local-test.sh inject-creds"
    FAIL=$((FAIL + 1))
    TESTS_RUN=$((TESTS_RUN + 1))
    return 1
  fi

  run_test \
    "AWS Storage Test (Tier 2)" \
    "${rgd}" \
    "${instance}" \
    "awsgen3storagetests.v1alpha1" \
    "awsgen3storagetest" \
    "storage-1" \
    "default" \
    "namespace//gen3-dev-test" \
    "keys.kms.services.k8s.aws/gen3-local-logging-key/gen3-dev-test" \
    "keys.kms.services.k8s.aws/gen3-local-platform-key/gen3-dev-test" \
    "buckets.s3.services.k8s.aws/gen3-local-logging-bucket/gen3-dev-test" \
    "buckets.s3.services.k8s.aws/gen3-local-data-bucket/gen3-dev-test" \
    "buckets.s3.services.k8s.aws/gen3-local-upload-bucket/gen3-dev-test" \
    "roles.iam.services.k8s.aws/gen3-local-eks-cluster-role/gen3-dev-test" \
    "roles.iam.services.k8s.aws/gen3-local-eks-node-role/gen3-dev-test"

  cleanup_test "${instance}" "${rgd}" "AWS Storage Test"
}

# =============================================================================
# Main
# =============================================================================
main() {
  local tier="${1:-all}"

  log_banner "gen3-dev RGD Validation"
  log_info "Context: $(kubectl config current-context 2>/dev/null || echo 'not set')"
  log_info "Cluster: $(kubectl cluster-info 2>/dev/null | head -1 || echo 'unreachable')"
  echo ""

  case "${tier}" in
    smoke)
      test_smoke
      ;;
    storage)
      test_storage
      ;;
    all)
      test_smoke
      echo ""
      test_storage
      ;;
    *)
      log_error "Unknown tier: ${tier}"
      echo "Usage: $0 {smoke|storage|all}"
      exit 1
      ;;
  esac

  # ── Summary ─────────────────────────────────────────────────────────────────
  echo ""
  log_banner "Validation Summary"
  log_info "Tests run: ${TESTS_RUN}"
  log_success "Passed:    ${PASS}"
  if [[ ${FAIL} -gt 0 ]]; then
    log_error "Failed:    ${FAIL}"
    exit 1
  else
    log_success "All tests passed!"
  fi
}

main "$@"
