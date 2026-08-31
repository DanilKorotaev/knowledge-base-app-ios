#!/usr/bin/env bash
# Regenerate KnowledgeBaseApp.xcodeproj from project.yml (required before build/test in CI).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

if [[ ! -f "$ROOT/project.yml" ]]; then
  echo "error: project.yml not found at $ROOT/project.yml" >&2
  exit 1
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    echo "xcodegen not found; installing via Homebrew..."
    brew install xcodegen
  else
    echo "error: xcodegen not found and Homebrew is unavailable" >&2
    exit 1
  fi
fi

xcodegen generate
echo "xcodegen generate: ok"
