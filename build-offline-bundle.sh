#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${1:-$SCRIPT_DIR/target.env}"
BUNDLE_PATH="${2:-$SCRIPT_DIR/service-migration-bundle.tar.gz}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing env file: $ENV_FILE" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$ENV_FILE"

for cmd in rsync tar mktemp; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "Missing required command: $cmd" >&2
    exit 1
  }
done

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT
bundle_root="$workdir/service-migration-bundle"
staging_dir="$bundle_root/staging"

mkdir -p "$bundle_root" "$staging_dir/systemd" "$staging_dir/etc" "$staging_dir/home"

rsync_common=(-a --delete --omit-dir-times --no-perms --no-owner --no-group)
rsync_data=("${rsync_common[@]}")

if [[ "${INCLUDE_GIT_DIRS:-0}" != "1" ]]; then
  rsync_data+=(--exclude=.git)
fi
if [[ "${INCLUDE_LOGS:-0}" != "1" ]]; then
  rsync_data+=(--exclude=logs --exclude='*.log')
fi

copy_tree() {
  local src="$1"
  local dest="$2"
  echo "Packing $src -> $dest"
  rsync "${rsync_data[@]}" "$src" "$dest"
}

copy_file() {
  local src="$1"
  local dest="$2"
  echo "Packing $src -> $dest"
  install -D "$src" "$dest"
}

rsync -a "$SCRIPT_DIR/" "$bundle_root/service-migration/"
cp "$ENV_FILE" "$bundle_root/service-migration/target.env"

if [[ "${SYNC_CLIPROXY:-1}" == "1" ]]; then
  copy_tree /home/juner122king/CLIProxyAPI/ "$staging_dir/home/CLIProxyAPI/"
fi

if [[ "${SYNC_NEWAPI:-1}" == "1" ]]; then
  copy_tree /home/juner122king/newapi/ "$staging_dir/home/newapi/"
fi

if [[ "${SYNC_CPA_DASHBOARD:-1}" == "1" ]]; then
  copy_tree /home/juner122king/CPA-Dashboard/ "$staging_dir/home/CPA-Dashboard/"
  copy_file /etc/systemd/system/cpa-dashboard.service "$staging_dir/systemd/cpa-dashboard.service"
fi

if [[ "${SYNC_SING_BOX:-1}" == "1" ]]; then
  copy_tree /etc/sing-box/ "$staging_dir/etc/sing-box/"
  copy_file /lib/systemd/system/sing-box.service "$staging_dir/systemd/sing-box.service"
fi

mkdir -p "$(dirname "$BUNDLE_PATH")"
tar -C "$workdir" -czf "$BUNDLE_PATH" service-migration-bundle

echo "Offline bundle created: $BUNDLE_PATH"
echo "Transfer it to the target host, then run:"
echo "  bash service-migration/extract-offline-bundle.sh $BUNDLE_PATH"
