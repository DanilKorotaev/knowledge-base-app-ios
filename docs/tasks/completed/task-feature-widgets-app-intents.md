# Widgets: App Intents (interactive)

**Status:** Done.

## Delivered

- **`StartVoiceRecordingIntent`** (`SharedIntents/`) — opens `knowledgebase://record` via `OpenURLIntent` (requires **iOS 18+**).
- **`KnowledgeBaseAppShortcuts`** — Shortcuts / Siri phrases (RU/EN), mic icon.
- Widget families use **`Button(intent: StartVoiceRecordingIntent())`** where the mic control appears (small, lock, medium).

## Acceptance

- [x] At least one `AppIntent` shared with the widget bundle (`SharedIntents` in app + widget targets).
- [x] Documented in root `README` (deployment) and `docs/DEVELOPMENT.md` (intent + plist note).
