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

TARGET_HOME="${TARGET_HOME:-$HOME}"
SERVICE_USER="${SERVICE_USER:-$USER}"
SERVICE_GROUP="${SERVICE_GROUP:-$USER}"
STAGING_DIR="$SCRIPT_DIR/staging"

for cmd in docker systemctl sudo rsync python3; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "Missing required command: $cmd" >&2
    exit 1
  }
done

if ! docker compose version >/dev/null 2>&1; then
  echo "docker compose plugin is required" >&2
  exit 1
fi

rewrite_cpa_unit() {
  local src="$STAGING_DIR/systemd/cpa-dashboard.service"
  local dest="$SCRIPT_DIR/cpa-dashboard.service.rendered"

  [[ -f "$src" ]] || return 0

  sed \
    -e "s|^User=.*$|User=$SERVICE_USER|" \
    -e "s|^Group=.*$|Group=$SERVICE_GROUP|" \
    -e "s|^WorkingDirectory=.*$|WorkingDirectory=$TARGET_HOME/CPA-Dashboard|" \
    -e "s|^ExecStart=.*$|ExecStart=/bin/bash $TARGET_HOME/CPA-Dashboard/start-linux.sh|" \
    "$src" > "$dest"
}

install_systemd_unit() {
  local rendered="$SCRIPT_DIR/cpa-dashboard.service.rendered"
  if [[ -f "$rendered" ]]; then
    sudo cp "$rendered" /etc/systemd/system/cpa-dashboard.service
  fi

  if [[ -f "$STAGING_DIR/systemd/sing-box.service" ]]; then
    sudo cp "$STAGING_DIR/systemd/sing-box.service" /etc/systemd/system/sing-box.service
  fi
}

install_sing_box_files() {
  if [[ -d "$STAGING_DIR/etc/sing-box" ]]; then
    sudo mkdir -p /etc/sing-box
    sudo rsync -a "$STAGING_DIR/etc/sing-box/" /etc/sing-box/
  fi
}

ensure_dashboard_venv() {
  if [[ -d "$TARGET_HOME/CPA-Dashboard" ]]; then
    if [[ ! -d "$TARGET_HOME/CPA-Dashboard/.venv" && ! -d "$TARGET_HOME/CPA-Dashboard/venv" ]]; then
      python3 -m venv "$TARGET_HOME/CPA-Dashboard/.venv"
    fi
  fi
}

start_compose_service() {
  local dir="$1"
  if [[ -f "$dir/docker-compose.yml" ]]; then
    (cd "$dir" && docker compose up -d)
  elif [[ -f "$dir/compose.yaml" ]]; then
    (cd "$dir" && docker compose up -d)
  fi
}

rewrite_cpa_unit
install_systemd_unit
install_sing_box_files
ensure_dashboard_venv
sudo systemctl daemon-reload

if [[ "${ENABLE_SERVICES:-1}" == "1" ]]; then
  if [[ -f /etc/systemd/system/cpa-dashboard.service ]]; then
    sudo systemctl enable cpa-dashboard.service
  fi
  if [[ -f /etc/systemd/system/sing-box.service ]]; then
    sudo systemctl enable sing-box.service
  fi
fi

if [[ "${SYNC_CLIPROXY:-1}" == "1" && -d "$TARGET_HOME/CLIProxyAPI" ]]; then
  start_compose_service "$TARGET_HOME/CLIProxyAPI"
fi

if [[ "${SYNC_NEWAPI:-1}" == "1" && -d "$TARGET_HOME/newapi" ]]; then
  start_compose_service "$TARGET_HOME/newapi"
fi

if [[ "${START_SERVICES:-1}" == "1" ]]; then
  if [[ -f /etc/systemd/system/cpa-dashboard.service ]]; then
    sudo systemctl restart cpa-dashboard.service
  fi
  if [[ -f /etc/systemd/system/sing-box.service ]]; then
    sudo systemctl restart sing-box.service
  fi
fi

if [[ -n "${TARGET_POST_INSTALL:-}" ]]; then
  bash -lc "$TARGET_POST_INSTALL"
fi

echo "Install complete. Run: $SCRIPT_DIR/check-services.sh $ENV_FILE"
