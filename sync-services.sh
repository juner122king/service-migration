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

required_vars=(TARGET_HOST TARGET_USER TARGET_SSH_PORT TARGET_HOME SERVICE_USER SERVICE_GROUP)
for var in "${required_vars[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    echo "Required variable $var is empty in $ENV_FILE" >&2
    exit 1
  fi
done

for cmd in rsync ssh; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "Missing required command: $cmd" >&2
    exit 1
  }
done

ssh_opts=(-p "$TARGET_SSH_PORT")
if [[ -n "${SSH_EXTRA_OPTS:-}" ]]; then
  # shellcheck disable=SC2206
  extra_opts=($SSH_EXTRA_OPTS)
  ssh_opts+=("${extra_opts[@]}")
fi

rsync_ssh=(ssh "${ssh_opts[@]}")
remote="$TARGET_USER@$TARGET_HOST"
staging_dir="$TARGET_HOME/service-migration/staging"
remote_script_dir="$TARGET_HOME/service-migration"

rsync_common=(-az --delete --mkpath --omit-dir-times --no-perms --no-owner --no-group -e "${rsync_ssh[*]}")
rsync_data=("${rsync_common[@]}")

if [[ "${INCLUDE_GIT_DIRS:-0}" != "1" ]]; then
  rsync_data+=(--exclude=.git)
fi
if [[ "${INCLUDE_LOGS:-0}" != "1" ]]; then
  rsync_data+=(--exclude=logs --exclude='*.log')
fi

run_rsync() {
  local src="$1"
  local dest="$2"
  echo "Syncing $src -> $dest"
  rsync "${rsync_data[@]}" "$src" "$dest"
}

run_file_rsync() {
  local src="$1"
  local dest="$2"
  echo "Syncing $src -> $dest"
  rsync "${rsync_common[@]}" "$src" "$dest"
}

ssh "${ssh_opts[@]}" "$remote" "mkdir -p '$remote_script_dir' '$staging_dir/systemd' '$staging_dir/etc'"

run_file_rsync "$SCRIPT_DIR/" "$remote:$remote_script_dir/"

if [[ "${SYNC_CLIPROXY:-1}" == "1" ]]; then
  run_rsync /home/juner122king/CLIProxyAPI/ "$remote:$TARGET_HOME/CLIProxyAPI/"
fi

if [[ "${SYNC_NEWAPI:-1}" == "1" ]]; then
  run_rsync /home/juner122king/newapi/ "$remote:$TARGET_HOME/newapi/"
fi

if [[ "${SYNC_CPA_DASHBOARD:-1}" == "1" ]]; then
  run_rsync /home/juner122king/CPA-Dashboard/ "$remote:$TARGET_HOME/CPA-Dashboard/"
  run_file_rsync /etc/systemd/system/cpa-dashboard.service "$remote:$staging_dir/systemd/cpa-dashboard.service"
fi

if [[ "${SYNC_SING_BOX:-1}" == "1" ]]; then
  run_rsync /etc/sing-box/ "$remote:$staging_dir/etc/sing-box/"
  run_file_rsync /lib/systemd/system/sing-box.service "$remote:$staging_dir/systemd/sing-box.service"
fi

cat <<INFO

Sync complete.
Next step on target:
  ssh -p $TARGET_SSH_PORT $remote 'bash $TARGET_HOME/service-migration/install-target.sh $TARGET_HOME/service-migration/target.env'

INFO
