#!/usr/bin/env bash
###############################################################################
# kro-status-report.sh — KRO + ACK Resource Status Report for gen3-dev
#
# Produces a structured report of:
#   1. KRO controller health
#   2. ResourceGraphDefinition (RGD) registry
#   3. Active KRO instance status (conditions + bridge ConfigMaps)
#   4. ACK-managed AWS resources per namespace (ARN + sync status)
#
# Usage:
#   bash scripts/kro-status-report.sh               # Full report (all namespaces)
#   bash scripts/kro-status-report.sh --ns gen3-foundation   # Single namespace
#   bash scripts/kro-status-report.sh --instance gen3-foundation  # Single instance
#   bash scripts/kro-status-report.sh --section kro          # kro | instances | ack
#   bash scripts/kro-status-report.sh --json ./report.json   # Dump JSON alongside report
#   bash scripts/kro-status-report.sh --out ./report.txt     # Write to file
#
# Mirrors kind-local-test.sh script structure and lib-logging.sh conventions.
###############################################################################
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="${REPO_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}"

# shellcheck source=lib-logging.sh
source "${SCRIPT_DIR}/lib-logging.sh"

# ── Argument Parsing ──────────────────────────────────────────────────────────
FILTER_NS=""
FILTER_INSTANCE=""
FILTER_SECTION=""   # kro | instances | ack | (empty = all)
JSON_OUT=""
FILE_OUT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ns)        FILTER_NS="$2";       shift 2 ;;
    --instance)  FILTER_INSTANCE="$2"; shift 2 ;;
    --section)   FILTER_SECTION="$2";  shift 2 ;;
    --json)      JSON_OUT="$2";        shift 2 ;;
    --out)       FILE_OUT="$2";        shift 2 ;;
    -h|--help)
      sed -n '4,14p' "$0" | sed 's/^# //'
      exit 0 ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
done

# ── Output Tee ────────────────────────────────────────────────────────────────
if [[ -n "${FILE_OUT}" ]]; then
  exec > >(tee "${FILE_OUT}") 2>&1
fi

# ── Helper: print separator ───────────────────────────────────────────────────
sep()      { echo "────────────────────────────────────────────────────────────────────"; }
sep_thin() { echo "  ┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈"; }

# ── Helper: kubectl quiet (no error on not-found) ─────────────────────────────
kget() { kubectl get "$@" 2>/dev/null || true; }
kdesc() { kubectl describe "$@" 2>/dev/null || true; }

# ── Helper: extract ACK condition value ──────────────────────────────────────
# usage: ack_condition <namespace> <resource-type> <resource-name> <condition-type>
ack_condition() {
  local ns="$1" restype="$2" resname="$3" condtype="$4"
  kubectl get "${restype}" "${resname}" -n "${ns}" \
    -o jsonpath="{.status.conditions[?(@.type==\"${condtype}\")].status}" 2>/dev/null \
    || echo "unknown"
}

# ── Helper: extract ACK ARN ──────────────────────────────────────────────────
ack_arn() {
  local ns="$1" restype="$2" resname="$3"
  kubectl get "${restype}" "${resname}" -n "${ns}" \
    -o jsonpath="{.status.ackResourceMetadata.arn}" 2>/dev/null \
    || echo "(not set)"
}

# ── Helper: print ACK resource table for a namespace ──────────────────────────
# usage: report_ack_resources <namespace>
report_ack_resources() {
  local ns="$1"

  # ACK resource types → (api-group, short-print-column header)
  local -A RESOURCE_TYPES=(
    ["vpcs.ec2.services.k8s.aws"]="VPC"
    ["internetgateways.ec2.services.k8s.aws"]="InternetGateway"
    ["elasticipaddresses.ec2.services.k8s.aws"]="ElasticIPAddress"
    ["natgateways.ec2.services.k8s.aws"]="NatGateway"
    ["routetables.ec2.services.k8s.aws"]="RouteTable"
    ["subnets.ec2.services.k8s.aws"]="Subnet"
    ["securitygroups.ec2.services.k8s.aws"]="SecurityGroup"
    ["keys.kms.services.k8s.aws"]="KMS Key"
    ["buckets.s3.services.k8s.aws"]="S3 Bucket"
    ["dbsubnetgroups.rds.services.k8s.aws"]="DBSubnetGroup"
    ["dbclusters.rds.services.k8s.aws"]="DBCluster"
    ["dbinstances.rds.services.k8s.aws"]="DBInstance"
    ["roles.iam.services.k8s.aws"]="IAM Role"
    ["policies.iam.services.k8s.aws"]="IAM Policy"
    ["secrets.secretsmanager.services.k8s.aws"]="SM Secret"
  )

  local any_found=0

  for restype in "${!RESOURCE_TYPES[@]}"; do
    local label="${RESOURCE_TYPES[${restype}]}"
    local items
    items=$(kget "${restype}" -n "${ns}" --no-headers 2>/dev/null) || continue
    [[ -z "${items}" ]] && continue
    any_found=1

    printf "  %-22s\n" "${label}"
    while IFS= read -r line; do
      local resname
      resname=$(echo "${line}" | awk '{print $1}')
      local synced
      synced=$(ack_condition "${ns}" "${restype}" "${resname}" "ACK.ResourceSynced")
      local terminal
      terminal=$(ack_condition "${ns}" "${restype}" "${resname}" "ACK.Terminal")
      local arn
      arn=$(ack_arn "${ns}" "${restype}" "${resname}")

      # Status icon
      local icon="·"
      [[ "${synced}" == "True" ]]  && icon="✓"
      [[ "${synced}" == "False" ]] && icon="✗"
      [[ "${terminal}" == "True" ]] && icon="!"

      printf "    %s  %-40s  synced=%-7s  %s\n" "${icon}" "${resname}" "${synced}" "${arn}"
    done <<< "${items}"
  done

  if [[ "${any_found}" -eq 0 ]]; then
    echo "  (no ACK resources found in namespace ${ns})"
  fi
}

# ── Helper: print KRO instance status ─────────────────────────────────────────
# usage: report_instance <kind> <name> <namespace>
report_instance() {
  local kind="$1" name="$2" ns="$3"

  # Map Kind → KRO plural (kubectl get uses plural CRD names)
  local plural
  plural=$(kubectl get crd --no-headers 2>/dev/null \
    | awk -v k="$(echo "${kind}" | tr '[:upper:]' '[:lower:]')" \
      'tolower($0) ~ k {print $1; exit}') || plural=""

  if [[ -z "${plural}" ]]; then
    log_warn "CRD for kind '${kind}' not found — RGD may not be installed yet"
    return
  fi

  echo ""
  echo "  Instance:  ${name}  (${kind})"
  echo "  Namespace: ${ns}"

  local status_ready
  status_ready=$(kubectl get "${plural}" "${name}" -n "${ns}" \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null \
    || echo "unknown")

  local status_reason
  status_reason=$(kubectl get "${plural}" "${name}" -n "${ns}" \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].reason}' 2>/dev/null \
    || echo "")

  local status_msg
  status_msg=$(kubectl get "${plural}" "${name}" -n "${ns}" \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].message}' 2>/dev/null \
    || echo "")

  local icon="·"
  [[ "${status_ready}" == "True" ]]  && icon="✓"
  [[ "${status_ready}" == "False" ]] && icon="✗"

  printf "  %s  Ready=%-7s  %s\n" "${icon}" "${status_ready}" "${status_reason}"
  [[ -n "${status_msg}" ]] && printf "     msg: %s\n" "${status_msg}"

  # Print full status section
  echo ""
  echo "  Status fields:"
  kubectl get "${plural}" "${name}" -n "${ns}" \
    -o jsonpath='{.status}' 2>/dev/null \
    | python3 -c "import sys,json; d=json.load(sys.stdin); [print(f'    {k}: {v}') for k,v in d.items() if k != 'conditions']" \
    2>/dev/null || echo "    (status not available)"

  # Print all conditions
  echo ""
  echo "  Conditions:"
  kubectl get "${plural}" "${name}" -n "${ns}" \
    -o jsonpath='{range .status.conditions[*]}    {.type}={.status}  {.reason}  {.message}{"\n"}{end}' \
    2>/dev/null || echo "    (no conditions)"
}

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 1 — KRO Controller
# ─────────────────────────────────────────────────────────────────────────────
section_kro() {
  log_banner "SECTION 1 — KRO Controller"

  log_stage "pods" "kro-system"
  kget pods -n kro-system -o wide
  echo ""

  log_stage "RGDs" "ResourceGraphDefinitions"
  kget resourcegraphdefinitions.kro.run --all-namespaces \
    -o custom-columns='NAME:.metadata.name,TOPOLOGICAL_ORDER:.status.topologicalOrder,READY:.status.conditions[?(@.type=="Ready")].status,AGE:.metadata.creationTimestamp' \
    2>/dev/null || kget resourcegraphdefinitions.kro.run --all-namespaces
  echo ""

  log_stage "RGD conditions" "any non-Ready"
  local rgds
  rgds=$(kubectl get resourcegraphdefinitions.kro.run -A --no-headers \
    -o custom-columns='NAME:.metadata.name' 2>/dev/null)
  while IFS= read -r rgd_name; do
    [[ -z "${rgd_name}" ]] && continue
    local ready
    ready=$(kubectl get resourcegraphdefinitions.kro.run "${rgd_name}" \
      -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null \
      || echo "unknown")
    if [[ "${ready}" != "True" ]]; then
      echo "  ⚠ ${rgd_name} — Ready=${ready}"
      kubectl get resourcegraphdefinitions.kro.run "${rgd_name}" \
        -o jsonpath='    reason={.status.conditions[?(@.type=="Ready")].reason}{"\n"}    msg={.status.conditions[?(@.type=="Ready")].message}{"\n"}' \
        2>/dev/null || true
    fi
  done <<< "${rgds}"
  echo ""
}

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 2 — ACK Controllers
# ─────────────────────────────────────────────────────────────────────────────
section_ack_controllers() {
  log_banner "SECTION 2 — ACK Controllers"

  local ack_namespaces=(
    "ack-ec2-controller"
    "ack-eks-controller"
    "ack-iam-controller"
    "ack-kms-controller"
    "ack-rds-controller"
    "ack-s3-controller"
    "ack-secretsmanager-controller"
  )

  printf "%-45s %-10s %-10s\n" "CONTROLLER" "READY" "PODS"
  sep_thin
  for ack_ns in "${ack_namespaces[@]}"; do
    local ready
    ready=$(kubectl get pods -n "${ack_ns}" --no-headers 2>/dev/null \
      | grep -c "Running" || echo 0)
    local total
    total=$(kubectl get pods -n "${ack_ns}" --no-headers 2>/dev/null \
      | wc -l | tr -d ' ' || echo 0)
    local status="✗"
    [[ "${ready}" -gt 0 ]] && status="✓"
    printf "%s  %-42s pods=%s/%s\n" "${status}" "${ack_ns}" "${ready}" "${total}"
  done
  echo ""
}

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 3 — Active KRO Instances
# ─────────────────────────────────────────────────────────────────────────────
# Enumerate known instances. Add new entries here as you deploy them.
section_instances() {
  log_banner "SECTION 3 — KRO Instance Status"

  # Format: "Kind|name|namespace"
  local INSTANCES=(
    # ── Production instances ──────────────────────────────────────────
    "AwsGen3Foundation1|gen3-foundation|gen3-foundation"
    # "AwsGen3Test1Flat|gen3-dev-test|gen3-dev-test"
    # "AwsGen3Database1|gen3-database|gen3-database"
    # "AwsGen3Compute1|gen3-compute|gen3-compute"
    # ── KRO capability tests ──────────────────────────────────────────
    # "KroForEachTest|kro-foreach-basic|kro-test-foreach"
    # "KroForEachTest|kro-foreach-cartesian|kro-test-foreach-cart"
    # "KroIncludeWhenTest|kro-includewhen-minimal|kro-test-includewhen"
    # "KroIncludeWhenTest|kro-includewhen-full|kro-test-includewhen-full"
    # "KroBridgeProducer|kro-bridge-producer|kro-test-bridge"
    # "KroBridgeConsumer|kro-bridge-consumer|kro-test-bridge"
    # "KroCELTest|kro-cel-dev|kro-test-cel"
    # "KroCELTest|kro-cel-prod|kro-test-cel-prod"
    # "KroTest06SgConditional|kro-sg-base-only|kro-test-sg"
    # "KroTest06SgConditional|kro-sg-all-features|kro-test-sg-full"
    # "KroTest07Producer|kro-crossrgd-producer|kro-test-crossrgd"
    # "KroTest07Consumer|kro-crossrgd-consumer|kro-test-crossrgd-consumer"
  )

  for entry in "${INSTANCES[@]}"; do
    # Skip commented entries (leading whitespace + #)
    [[ "${entry}" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${entry}" ]] && continue

    IFS='|' read -r kind name ns <<< "${entry}"

    # Apply instance filter
    if [[ -n "${FILTER_INSTANCE}" && "${name}" != "${FILTER_INSTANCE}" ]]; then
      continue
    fi

    sep
    report_instance "${kind}" "${name}" "${ns}"
    echo ""
  done

  # Bridge ConfigMaps across all known namespaces
  sep
  echo ""
  log_stage "bridge ConfigMaps" "all namespaces"
  kget configmap --all-namespaces \
    -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,AGE:.metadata.creationTimestamp' \
    | grep -E "(bridge|crossrgd)" || echo "  (none found)"
  echo ""
}

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 4 — ACK AWS Resources Per Namespace
# ─────────────────────────────────────────────────────────────────────────────
section_ack_resources() {
  log_banner "SECTION 4 — ACK-Managed AWS Resources"

  # Namespaces to scan. Extend as you add instances.
  local NAMESPACES=(
    "gen3-foundation"
    "gen3-database"
    "gen3-compute"
    "gen3-dev-test"
    "kro-test-sg"
    "kro-test-sg-full"
    "kro-test-crossrgd"
    "kro-test-crossrgd-consumer"
  )

  for ns in "${NAMESPACES[@]}"; do
    # Apply namespace filter
    if [[ -n "${FILTER_NS}" && "${ns}" != "${FILTER_NS}" ]]; then
      continue
    fi

    # Skip if namespace doesn't exist
    kubectl get namespace "${ns}" &>/dev/null || continue

    sep
    echo ""
    log_stage "namespace" "${ns}"
    echo ""
    report_ack_resources "${ns}"
    echo ""
  done
}

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 5 — ArgoCD Application Health
# ─────────────────────────────────────────────────────────────────────────────
section_argocd() {
  log_banner "SECTION 5 — ArgoCD Application Health"

  kget applications.argoproj.io -n argocd \
    -o custom-columns='NAME:.metadata.name,HEALTH:.status.health.status,SYNC:.status.sync.status,REVISION:.status.sync.revision' \
    2>/dev/null || log_warn "ArgoCD not installed or no applications found"
  echo ""

  # Highlight degraded / out-of-sync apps
  local degraded
  degraded=$(kubectl get applications.argoproj.io -n argocd --no-headers \
    -o custom-columns='NAME:.metadata.name,HEALTH:.status.health.status,SYNC:.status.sync.status' \
    2>/dev/null | grep -vE "(Healthy|Synced)" || true)
  if [[ -n "${degraded}" ]]; then
    echo ""
    log_warn "Degraded or out-of-sync applications:"
    echo "${degraded}"
  fi
  echo ""
}

# ─────────────────────────────────────────────────────────────────────────────
# JSON dump helper
# ─────────────────────────────────────────────────────────────────────────────
dump_json() {
  [[ -z "${JSON_OUT}" ]] && return

  log_info "Collecting JSON snapshot → ${JSON_OUT}"

  local tmpdir
  tmpdir=$(mktemp -d)

  # RGDs
  kubectl get resourcegraphdefinitions.kro.run -A -o json \
    > "${tmpdir}/rgds.json" 2>/dev/null || echo '{}' > "${tmpdir}/rgds.json"

  # ArgoCD apps
  kubectl get applications.argoproj.io -n argocd -o json \
    > "${tmpdir}/argocd.json" 2>/dev/null || echo '{}' > "${tmpdir}/argocd.json"

  # ACK resources from all relevant namespaces
  local ns_list=("gen3-foundation" "gen3-database" "gen3-compute" "gen3-dev-test"
                 "kro-test-sg" "kro-test-sg-full" "kro-test-crossrgd" "kro-test-crossrgd-consumer")

  local ack_types=(
    "vpcs.ec2.services.k8s.aws"
    "internetgateways.ec2.services.k8s.aws"
    "elasticipaddresses.ec2.services.k8s.aws"
    "natgateways.ec2.services.k8s.aws"
    "routetables.ec2.services.k8s.aws"
    "subnets.ec2.services.k8s.aws"
    "securitygroups.ec2.services.k8s.aws"
    "keys.kms.services.k8s.aws"
    "buckets.s3.services.k8s.aws"
    "dbsubnetgroups.rds.services.k8s.aws"
    "dbclusters.rds.services.k8s.aws"
    "dbinstances.rds.services.k8s.aws"
    "roles.iam.services.k8s.aws"
    "policies.iam.services.k8s.aws"
    "secrets.secretsmanager.services.k8s.aws"
  )

  local combined_ack='{"items":[]}'
  for ns in "${ns_list[@]}"; do
    kubectl get namespace "${ns}" &>/dev/null || continue
    for restype in "${ack_types[@]}"; do
      local items
      items=$(kubectl get "${restype}" -n "${ns}" -o json 2>/dev/null || echo '{"items":[]}')
      combined_ack=$(echo "${combined_ack}" "${items}" \
        | python3 -c "import sys,json; a,b=json.load(sys.stdin).items() if False else [json.loads(l) for l in sys.stdin.read().split('\n') if l.strip()]; a['items']+=b.get('items',[]); print(json.dumps(a))" \
        2>/dev/null || echo "${combined_ack}")
    done
  done

  python3 -c "
import json, sys
rgds    = json.load(open('${tmpdir}/rgds.json'))
argocd  = json.load(open('${tmpdir}/argocd.json'))
report  = {
  'generatedAt': '$(date -u +%Y-%m-%dT%H:%M:%SZ)',
  'cluster':     '${KIND_CLUSTER_NAME:-gen3-local}',
  'rgds':        rgds.get('items', []),
  'argoCDApps':  argocd.get('items', []),
}
with open('${JSON_OUT}', 'w') as f:
  json.dump(report, f, indent=2)
print('  Wrote', '${JSON_OUT}')
" 2>/dev/null || log_warn "JSON dump failed (python3 required)"

  rm -rf "${tmpdir}"
}

# ─────────────────────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────────────────────
main() {
  log_banner "gen3-dev KRO Status Report — $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "  Cluster:    ${KIND_CLUSTER_NAME:-gen3-local}"
  echo "  KUBECONFIG: ${KUBECONFIG:-~/.kube/config}"
  echo "  Filter:     ns=${FILTER_NS:-*}  instance=${FILTER_INSTANCE:-*}  section=${FILTER_SECTION:-all}"
  echo ""

  # Verify cluster is reachable
  if ! kubectl cluster-info &>/dev/null; then
    log_error "Cannot reach cluster. Is the Kind cluster running?"
    log_info  "Run: docker start gen3-local-control-plane"
    exit 1
  fi

  case "${FILTER_SECTION}" in
    kro)       section_kro ;;
    ack)       section_ack_controllers; section_ack_resources ;;
    argocd)    section_argocd ;;
    instances) section_instances ;;
    "")
      section_kro
      section_ack_controllers
      section_instances
      section_ack_resources
      section_argocd
      ;;
    *) log_error "Unknown section '${FILTER_SECTION}'. Valid: kro | ack | instances | argocd"; exit 1 ;;
  esac

  dump_json

  sep
  log_success "Report complete."
}

main "$@"
