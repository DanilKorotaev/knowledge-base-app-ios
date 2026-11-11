#!/bin/sh
# Writes GoogleService-Info.plist from FIREBASE_GOOGLE_SERVICE_INFO_PLIST_BASE64.
# An empty secret leaves Crashlytics off and does not fail the build.
set -eu

DEST="KnowledgeBaseApp/Resources/GoogleService-Info.plist"
if [ -z "${FIREBASE_GOOGLE_SERVICE_INFO_PLIST_BASE64:-}" ]; then
  echo "note: Firebase plist secret is empty; Crashlytics stays off"
  exit 0
fi

mkdir -p KnowledgeBaseApp/Resources
printf '%s' "$FIREBASE_GOOGLE_SERVICE_INFO_PLIST_BASE64" | base64 --decode > "$DEST"
echo "note: wrote ${DEST}"
