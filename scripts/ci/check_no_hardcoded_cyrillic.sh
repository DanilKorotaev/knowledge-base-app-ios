#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

PATTERN='"[^"]*[А-Яа-яЁё][^"]*"'
SCAN_PATHS=(
  KnowledgeBaseApp/Views
  KnowledgeBaseApp/ViewModels
  KnowledgeBaseApp/Models
  KnowledgeBaseApp/Services
  KnowledgeBaseApp/App
)

ALLOWLIST=(
  'KnowledgeBaseApp/App/KnowledgeBaseAppShortcuts.swift'
)

fail=0
for path in "${SCAN_PATHS[@]}"; do
  while IFS= read -r file; do
    for allowed in "${ALLOWLIST[@]}"; do
      if [[ "$file" == "$allowed" ]]; then
        continue 2
      fi
    done
    if grep -qE "$PATTERN" "$file"; then
      echo "Hard-coded Cyrillic in $file:"
      grep -nE "$PATTERN" "$file" || true
      fail=1
    fi
  done < <(find "$path" -name '*.swift' -type f | sort)
done

if [[ "$fail" -ne 0 ]]; then
  echo "Add user-facing copy to SharedLocalization/Localizable.xcstrings instead of inline Russian."
  exit 1
fi

echo "No unexpected Cyrillic UI literals found."
