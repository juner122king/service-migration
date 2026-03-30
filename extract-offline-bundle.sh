#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLE_PATH="${1:-}"
EXTRACT_ROOT="${2:-$HOME/service-migration-offline}"

if [[ -z "$BUNDLE_PATH" ]]; then
  echo "Usage: $0 /path/to/service-migration-bundle.tar.gz [extract-root]" >&2
  exit 1
fi

if [[ ! -f "$BUNDLE_PATH" ]]; then
  echo "Bundle not found: $BUNDLE_PATH" >&2
  exit 1
fi

for cmd in tar rsync; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "Missing required command: $cmd" >&2
    exit 1
  }
done

mkdir -p "$EXTRACT_ROOT"
tar -C "$EXTRACT_ROOT" -xzf "$BUNDLE_PATH"

bundle_dir="$EXTRACT_ROOT/service-migration-bundle"
kit_dir="$bundle_dir/service-migration"
staging_dir="$bundle_dir/staging"

if [[ ! -d "$kit_dir" || ! -d "$staging_dir" ]]; then
  echo "Bundle is missing expected directories" >&2
  exit 1
fi

rsync -a "$kit_dir/" "$SCRIPT_DIR/"
mkdir -p "$SCRIPT_DIR/staging"
rsync -a "$staging_dir/" "$SCRIPT_DIR/staging/"

if [[ -f "$kit_dir/target.env" ]]; then
  cp "$kit_dir/target.env" "$SCRIPT_DIR/target.env"
fi

echo "Bundle extracted into: $SCRIPT_DIR"
echo "Next steps:"
echo "  1. Review $SCRIPT_DIR/target.env"
echo "  2. Optional bootstrap: sudo bash $SCRIPT_DIR/bootstrap-target.sh"
echo "  3. Install: bash $SCRIPT_DIR/install-target.sh $SCRIPT_DIR/target.env"
echo "  4. Validate: bash $SCRIPT_DIR/check-services.sh $SCRIPT_DIR/target.env"
