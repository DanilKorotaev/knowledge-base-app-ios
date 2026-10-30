#!/usr/bin/env bash
# Soft SwiftLint gate (`.swiftlint.yml`). Must exit 0 with zero violations.
# Strict inventory: `swiftlint lint --config .swiftlint-strict.yml`
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

if ! command -v swiftlint >/dev/null 2>&1; then
  echo "error: swiftlint not found on PATH" >&2
  echo "Install: brew install swiftlint" >&2
  exit 127
fi

CONFIG="${SWIFTLINT_CONFIG:-.swiftlint.yml}"
echo "Running SwiftLint with config: ${CONFIG} (swiftlint $(swiftlint version))"
# --strict: treat warnings as errors so CI fails on any soft-config hit.
swiftlint lint --config "$CONFIG" --strict --reporter xcode
