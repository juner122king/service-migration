#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${1:-$SCRIPT_DIR/target.env}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing env file: $ENV_FILE" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$ENV_FILE"

check_url() {
  local label="$1"
  local url="$2"
  if command -v curl >/dev/null 2>&1 && curl -fsS --max-time 5 "$url" >/dev/null; then
    echo "OK  $label $url"
  else
    echo "ERR $label $url"
    return 1
  fi
}

check_tcp() {
  local label="$1"
  local host="$2"
  local port="$3"
  if timeout 3 bash -lc "</dev/tcp/$host/$port" >/dev/null 2>&1; then
    echo "OK  tcp $label $host:$port"
  else
    echo "ERR tcp $label $host:$port"
    return 1
  fi
}

check_systemd() {
  local unit="$1"
  if systemctl is-active --quiet "$unit"; then
    echo "OK  systemd $unit"
  else
    echo "ERR systemd $unit"
    return 1
  fi
}

check_docker() {
  local name="$1"
  if docker ps --format '{{.Names}}' | grep -Fx "$name" >/dev/null 2>&1; then
    echo "OK  docker $name"
  else
    echo "ERR docker $name"
    return 1
  fi
}

status=0

if [[ "${SYNC_CLIPROXY:-1}" == "1" ]]; then
  check_docker cli-proxy-api || status=1
  check_tcp CLIProxyAPI 127.0.0.1 8317 || status=1
fi

if [[ "${SYNC_NEWAPI:-1}" == "1" ]]; then
  check_docker new-api || status=1
  check_url new-api http://127.0.0.1:3480/api/status || status=1
fi

if [[ "${SYNC_CPA_DASHBOARD:-1}" == "1" ]]; then
  check_systemd cpa-dashboard.service || status=1
  check_tcp CPA-Dashboard 127.0.0.1 5000 || status=1
fi

if [[ "${SYNC_SING_BOX:-1}" == "1" ]]; then
  check_systemd sing-box.service || status=1
fi

exit "$status"
