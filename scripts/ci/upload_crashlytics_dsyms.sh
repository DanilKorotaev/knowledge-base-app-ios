#!/bin/sh
# Uploads dSYMs when GoogleService-Info.plist is present.
#
# Firebase's Crashlytics/run launches upload-symbols in the background and
# hides its output. On GitHub Actions that process is still running when the
# job ends, and the runner kills it. Call upload-symbols in the foreground.
#
# CI passes the exported dSYM zip as $1 after gym. A local archive has no
# argument and uses the Xcode build-phase environment.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
PLIST="${SRCROOT:-$ROOT}/KnowledgeBaseApp/Resources/GoogleService-Info.plist"
if [ ! -f "$PLIST" ]; then
  PLIST="$ROOT/KnowledgeBaseApp/Resources/GoogleService-Info.plist"
fi
if [ ! -f "$PLIST" ]; then
  echo "note: Crashlytics dSYM upload skipped (no GoogleService-Info.plist)"
  exit 0
fi

find_tool() {
  find "${HOME}/Library/Developer/Xcode/DerivedData" \
    -path '*/firebase-ios-sdk/Crashlytics/upload-symbols' -type f -print -quit 2>/dev/null || true
}

if [ -n "${1:-}" ]; then
  TOOL=$(find_tool)
  if [ -z "$TOOL" ]; then
    echo "error: upload-symbols was not found after the archive build"
    exit 1
  fi
  echo "note: uploading Crashlytics dSYMs from $1"
  "$TOOL" -gsp "$PLIST" -p ios "$1"
  exit 0
fi

case "${ACTION:-}" in
  install) ;;
  *)
    echo "note: Crashlytics dSYM upload skipped for ACTION=${ACTION:-unknown}"
    exit 0
    ;;
esac

if [ "${CI:-}" = "true" ]; then
  echo "note: Crashlytics dSYM upload runs after the archive is exported"
  exit 0
fi

TOOL="${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/upload-symbols"
if [ ! -x "$TOOL" ]; then
  echo "error: upload-symbols not found at $TOOL"
  exit 1
fi
"$TOOL" --build-phase --validate -gsp "$PLIST"
"$TOOL" --build-phase -gsp "$PLIST"
