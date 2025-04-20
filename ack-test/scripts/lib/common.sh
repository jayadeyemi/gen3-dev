#!/usr/bin/env bash
set -euo pipefail

# Global values
AWS_REGION="us-east-1"
EKS_CLUSTER_NAME="my-cluster"
ACK_SYSTEM_NAMESPACE="ack-system"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")/.."

# Load env once everywhere
if [[ -f "$ROOT_DIR/scripts/etc/config.env" ]]; then
  # shellcheck disable=SC1091
  source "$ROOT_DIR/scripts/etc/config.env"
else
  echo "env/config.env missing"; exit 1
fi

# create a log file
LOG_FILE="/var/log/ack-test.log"
# create a log file if it doesn't exist
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
fi
# add a log to log file
# Simple coloured logger
log() { printf "\e[1;34m[%-7s]\e[0m %s\n" "$1" "$2"; 
# add log to log file
echo "$(date +'%Y-%m-%d %H:%M:%S') [$1] $2" >> "$LOG_FILE"; }


