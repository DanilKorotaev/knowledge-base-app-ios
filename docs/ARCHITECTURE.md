# Architecture

## Goal

Alternative **iOS client** to the same knowledge base infrastructure as the Telegram bot:

- Shared **PostgreSQL** (sessions, messages) — once KB App API exists.
- Same **Cursor CLI** / processing services on the server.
- **Nextcloud WebDAV** and **Whisper** transcription remain server-side concerns.

The app talks only to **HTTPS APIs**; it does not run Cursor or touch the database directly.

## Current implementation

| Area | Status |
|------|--------|
| SwiftUI shell (`MainView`, `SettingsView`) | Initial |
| `AppConfiguration` | `KBAPP_*` env; URL в UserDefaults; **токен** — Keychain (+ миграция с UserDefaults) |
| `KnowledgeBaseAPIClientProtocol` | Sessions list + create session |
| `StubKnowledgeBaseAPIClient` + `InMemoryKBStore` | Demo session when no base URL |
| `URLSessionKnowledgeBaseAPIClient` | `GET/POST /api/sessions`, messages, attachments, files |
| `ChatAPIClientProtocol` | Messages + `streamTextMessage` / send + attachments (stub + `URLSession` same host) |
| `SSEventParser` / `ChatSSEEvent` | SSE `data:` + JSON `delta`/`done` для `POST …/messages` с `Accept: text/event-stream` |
| `ChatView` / `ChatViewModel` | Thread + composer + gallery + **camera** + file importer |
| `NewSessionSheet` | Create session (stub / `POST /api/sessions`) |
| `KBSession`, `KBMessage` | REST-oriented models |
| `FilesAPIClientProtocol` | Changed files + revert (stub + `GET/POST …/api/files/…`) |
| `ChangedFilesView` / `FileDiffView` | List, before/after, revert |
| Widget extension | Small / medium / lock screen; mic via **`StartVoiceRecordingIntent`** → `knowledgebase://record` |
| Deep link | Opens app, shows voice hint banner on main screen |

## Voice (partial)

| Piece | Status |
|-------|--------|
| `VoiceRecordingService` | AAC to temp file, metering |
| `VoiceRecordingViewModel` + `MicRecordControl` | Hold / cancel / lock, review sheet |
| `ChatAPIClientProtocol.sendVoiceRecording` | `VoiceRecordingSendResult` — stub + `POST /api/query/voice` (multipart + опц. `transcription` в JSON) |
| `VoiceRoutingContext` | Active chat session + KB toggle for voice send |
| `kbSessionThreadDidChange` | Voice send notifies open `ChatView` + session list to refetch |

## Next (product / backend)

- **Voice (remaining)** — multipart upload + Whisper-backed transcription text (KB App API + bot services).
- **Chat** — серверный SSE по `text/event-stream` (prod; см. `tasks/completed/task-feature-chat.md`); WebSocket — только если понадобится отдельно от SSE.

## Backend boundary

Canonical HTTP contract for this app: **`docs/KB_APP_API_CONTRACT.md`** and **`docs/openapi/kb-app-api.yaml`**. Higher-level product notes remain in Nextcloud («Архитектура и бэкенд API»).

**KB App API** is implemented in `knowledge-base-bot/kb_app_api/`. Without `KBAPP_API_BASE_URL`, the app uses the in-memory stub client. With base URL + Bearer token, it uses `URLSessionKnowledgeBaseAPIClient`. Keep paths and JSON aligned with the repo contract in the same change as server updates. Deploy checklist: Nextcloud `Документация/Задачи/KB App API — бэкенд для iOS/Чеклист — деплой и интеграция.md`.

Open choice for the repo layout (documented in Nextcloud tasks folder): separate `kb-app-api` service importing bot services vs. later merge into a gateway.

## Constraints (mandatory)

- Services expose protocols; dependencies are injected.
- New logic ships with tests (see `CODING_STANDARDS.md`).
