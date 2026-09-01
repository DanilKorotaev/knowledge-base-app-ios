#!/usr/bin/env bash
# Fail CI if XcodeGen wiped required entitlements (regression guard).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MAIN_ENT="$ROOT/KnowledgeBaseApp/KnowledgeBaseApp.entitlements"
WIDGET_ENT="$ROOT/KnowledgeBaseWidget/KnowledgeBaseWidget.entitlements"

require_key() {
  local file="$1"
  local key="$2"
  if ! /usr/libexec/PlistBuddy -c "Print :${key}" "$file" >/dev/null 2>&1; then
    echo "error: missing ${key} in ${file}" >&2
    exit 1
  fi
}

for file in "$MAIN_ENT" "$WIDGET_ENT"; do
  if [[ ! -f "$file" ]]; then
    echo "error: entitlements file not found: $file" >&2
    exit 1
  fi
done

require_key "$MAIN_ENT" "com.apple.developer.healthkit"
require_key "$MAIN_ENT" "com.apple.developer.healthkit.background-delivery"
require_key "$MAIN_ENT" "com.apple.security.application-groups"
require_key "$WIDGET_ENT" "com.apple.security.application-groups"

echo "verify_entitlements: ok"
