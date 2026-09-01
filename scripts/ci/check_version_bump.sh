#!/usr/bin/env bash
# On pull requests: if app sources changed vs base, require VERSION and CHANGELOG.md changes.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

if [[ "${GITHUB_EVENT_NAME:-}" != "pull_request" && -z "${FORCE_VERSION_CHECK:-}" ]]; then
  echo "Skipping version bump check (not a pull_request)."
  exit 0
fi

BASE_REF="${VERSION_CHECK_BASE:-}"
if [[ -z "$BASE_REF" ]]; then
  if [[ -n "${GITHUB_BASE_REF:-}" ]]; then
    BASE_REF="origin/${GITHUB_BASE_REF}"
  else
    BASE_REF="origin/main"
  fi
fi

git rev-parse --verify "$BASE_REF" >/dev/null 2>&1 || git fetch --no-tags origin "$(echo "$BASE_REF" | sed 's#^origin/##')" || true

if ! git rev-parse --verify "$BASE_REF" >/dev/null 2>&1; then
  echo "error: cannot resolve base ref $BASE_REF" >&2
  exit 1
fi

CHANGED="$(git diff --name-only "$BASE_REF"...HEAD)"

APP_PATH_REGEX='^(KnowledgeBaseApp/|SharedIntents/|SharedWatchConnectivity/|SharedLocalization/|KnowledgeBaseWatchApp/|KnowledgeBaseWatchWidget/|KnowledgeBaseWidget/|project\.yml$)'

if ! echo "$CHANGED" | grep -E "$APP_PATH_REGEX" >/dev/null; then
  echo "No app source changes requiring a version bump."
  exit 0
fi

need_version=0
need_changelog=0

if ! echo "$CHANGED" | grep -qx 'VERSION'; then
  need_version=1
fi
if ! echo "$CHANGED" | grep -qx 'CHANGELOG.md'; then
  need_changelog=1
fi

if [[ "$need_version" -eq 0 && "$need_changelog" -eq 0 ]]; then
  BASE_VERSION="$(git show "$BASE_REF:VERSION" 2>/dev/null | tr -d '[:space:]' || true)"
  HEAD_VERSION="$(tr -d '[:space:]' < VERSION)"
  if [[ -n "$BASE_VERSION" && "$BASE_VERSION" == "$HEAD_VERSION" ]]; then
    echo "error: VERSION file changed in the PR but value is still '$HEAD_VERSION' (same as $BASE_REF)." >&2
    exit 1
  fi
  echo "VERSION and CHANGELOG.md updated for app changes."
  exit 0
fi

echo "error: app sources changed vs $BASE_REF but release metadata is incomplete." >&2
echo "Changed app-related paths:" >&2
echo "$CHANGED" | grep -E "$APP_PATH_REGEX" >&2 || true
if [[ "$need_version" -eq 1 ]]; then
  echo "  - bump root VERSION (SemVer)" >&2
fi
if [[ "$need_changelog" -eq 1 ]]; then
  echo "  - add an entry in CHANGELOG.md" >&2
fi
echo "See docs/RELEASE_PROCESS.md" >&2
exit 1
