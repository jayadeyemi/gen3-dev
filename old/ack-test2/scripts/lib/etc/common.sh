#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")/.."

# create a log file if it doesn't exist
LOG_FILE="/ack-test.log"

if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
fi
# Simple coloured logger
log() { printf "\e[1;34m[%-7s]\e[0m %s\n" "$1" "$2"; 
echo "$(date +'%Y-%m-%d %H:%M:%S') [$1] $2" >> "$LOG_FILE"; }


