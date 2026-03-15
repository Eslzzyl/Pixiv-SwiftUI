#!/bin/bash

set -euo pipefail

show_help() {
  cat <<'EOF'
Usage: update_homebrew_cask.sh --tap-path PATH --version VERSION --arm64-sha SHA --intel-sha SHA

Updates Casks/pixiv-swiftui.rb in a local homebrew-tap checkout.

Required arguments:
  --tap-path     Path to the homebrew-tap repository
  --version      Version without leading v
  --arm64-sha    SHA256 for Pixiv-SwiftUI-arm64.dmg
  --intel-sha    SHA256 for Pixiv-SwiftUI-x86_64.dmg
EOF
}

TAP_PATH=""
VERSION=""
ARM64_SHA=""
INTEL_SHA=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tap-path)
      TAP_PATH="$2"
      shift 2
      ;;
    --version)
      VERSION="$2"
      shift 2
      ;;
    --arm64-sha)
      ARM64_SHA="$2"
      shift 2
      ;;
    --intel-sha)
      INTEL_SHA="$2"
      shift 2
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      show_help >&2
      exit 1
      ;;
  esac
done

if [[ -z "$TAP_PATH" || -z "$VERSION" || -z "$ARM64_SHA" || -z "$INTEL_SHA" ]]; then
  show_help >&2
  exit 1
fi

CASK_PATH="$TAP_PATH/Casks/pixiv-swiftui.rb"

if [[ ! -f "$CASK_PATH" ]]; then
  echo "Cask file not found: $CASK_PATH" >&2
  exit 1
fi

export CASK_PATH VERSION ARM64_SHA INTEL_SHA

python3 - <<'PY'
import os
import re
from pathlib import Path

cask_path = Path(os.environ["CASK_PATH"])
content = cask_path.read_text(encoding="utf-8")

content = re.sub(r'version "[^"]+"', f'version "{os.environ["VERSION"]}"', content, count=1)
content = re.sub(
    r'sha256 arm:\s+"[0-9a-f]+",\n\s+intel: "[0-9a-f]+"',
    'sha256 arm:   "{arm}",\n         intel: "{intel}"'.format(
        arm=os.environ["ARM64_SHA"],
        intel=os.environ["INTEL_SHA"],
    ),
    content,
    count=1,
)

cask_path.write_text(content, encoding="utf-8")
PY

echo "Updated $CASK_PATH to version $VERSION"
