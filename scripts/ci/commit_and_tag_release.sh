#!/usr/bin/env bash
# After a successful TestFlight upload: commit VERSION/CHANGELOG/RELEASES and push tag ios/v*.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

VERSION="$(tr -d '[:space:]' < VERSION)"
TAG="ios/v${VERSION}"
BRANCH="${GITHUB_REF_NAME:-main}"
if [[ "$BRANCH" == "refs/heads/"* ]]; then
  BRANCH="${BRANCH#refs/heads/}"
fi
# workflow_run checkouts are detached at head_sha; publish release metadata to main tip
if [[ "${GITHUB_EVENT_NAME:-}" == "workflow_run" ]]; then
  BRANCH="main"
fi

git config user.name "${GIT_AUTHOR_NAME:-github-actions[bot]}"
git config user.email "${GIT_AUTHOR_EMAIL:-github-actions[bot]@users.noreply.github.com}"

BUILD=""
META="$ROOT/fastlane/test_output/ci_testflight.json"
if [[ -f "$META" ]]; then
  BUILD="$(python3 -c "import json,pathlib; print(json.loads(pathlib.Path('fastlane/test_output/ci_testflight.json').read_text()).get('build_number',''))" 2>/dev/null || true)"
fi

update_releases_build_column() {
  if [[ -z "$BUILD" || ! -f docs/RELEASES.md ]]; then
    return 0
  fi
  VERSION="$VERSION" BUILD="$BUILD" python3 - <<'PY'
import os
import re
from pathlib import Path

path = Path("docs/RELEASES.md")
version = os.environ["VERSION"]
build = os.environ["BUILD"]
text = path.read_text(encoding="utf-8")
pattern = rf"^(\|\s*{re.escape(version)}\s*\|\s*)[^|]*(\|)"
text2, n = re.subn(pattern, rf"\g<1>{build} \2", text, count=1, flags=re.M)
if n:
    path.write_text(text2, encoding="utf-8")
    print(f"RELEASES.md build -> {build}")
PY
}

sync_to_origin_branch() {
  git fetch origin "${BRANCH}"
  if git show-ref --verify --quiet "refs/remotes/origin/${BRANCH}"; then
    # Always rebase onto tip — deploy checkouts are usually detached at head_sha.
    git rebase "origin/${BRANCH}"
  fi
}

discard_deploy_working_tree() {
  # prepare_release / fastlane beta touch tracked files we must not push (xcodeproj, project.yml).
  if [[ -n "$(git status --porcelain)" ]]; then
    echo "Discarding local deploy-only changes before rebase:"
    git status --porcelain
    git reset --hard HEAD
    git clean -fd --exclude=.git --exclude=vendor --exclude=fastlane/test_output --exclude=fastlane/build_logs 2>/dev/null || git clean -fd
  fi
}

update_releases_build_column

git add VERSION CHANGELOG.md docs/RELEASES.md
if [[ -n "$(git status --porcelain -- VERSION CHANGELOG.md docs/RELEASES.md)" ]]; then
  MSG="chore(release): ios/v${VERSION}"
  if [[ -n "$BUILD" ]]; then
    MSG="${MSG} (build ${BUILD})"
  fi
  MSG="${MSG} [skip ci]"
  git commit -m "$MSG"
  echo "Created release commit on $(git rev-parse --short HEAD)"

  discard_deploy_working_tree
  # Deploy often runs on detached HEAD while main moved (fix commits, docs). Rebase first.
  sync_to_origin_branch
  git push origin "HEAD:${BRANCH}"
  echo "Pushed release commit for ${VERSION} -> ${BRANCH}"
else
  echo "No release metadata changes to commit."
  git fetch origin "${BRANCH}" 2>/dev/null || true
fi

git fetch --tags --force origin 2>/dev/null || true
if git ls-remote --exit-code --tags origin "refs/tags/${TAG}" >/dev/null 2>&1; then
  echo "Tag ${TAG} already exists on origin; skip create."
  exit 0
fi

MSG="iOS ${VERSION}"
if [[ -n "$BUILD" ]]; then
  MSG="iOS ${VERSION} (build ${BUILD})"
fi
git tag -a "$TAG" -m "$MSG"
git push origin "refs/tags/${TAG}"
echo "Created and pushed tag ${TAG}"
