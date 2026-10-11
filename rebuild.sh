#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
KIT="${MENUBAR_KIT:-$(cd ../menubar-kit 2>/dev/null && pwd)}" \
  || { echo "menubar-kit not found: clone it next to this repo or set MENUBAR_KIT" >&2; exit 1; }
exec "$KIT/scripts/rebuild.sh" ClaudeUsage
