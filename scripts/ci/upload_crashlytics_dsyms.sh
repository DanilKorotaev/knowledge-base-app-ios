#!/bin/sh
# Uploads dSYMs when GoogleService-Info.plist is present. A missing plist skips the step.
set -eu

PLIST="${SRCROOT}/KnowledgeBaseApp/Resources/GoogleService-Info.plist"
if [ ! -f "$PLIST" ]; then
  echo "note: Crashlytics dSYM upload skipped (no GoogleService-Info.plist)"
  exit 0
fi

case "${ACTION:-}" in
  install) ;;
  *)
    echo "note: Crashlytics dSYM upload skipped for ACTION=${ACTION:-unknown}"
    exit 0
    ;;
esac

RUN_SCRIPT="${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"
if [ ! -f "$RUN_SCRIPT" ]; then
  echo "note: Crashlytics run script is not in SourcePackages"
  exit 0
fi

export GOOGLE_SERVICE_INFO_PLIST="$PLIST"
"$RUN_SCRIPT"
