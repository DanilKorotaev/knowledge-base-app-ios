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
| `AppConfiguration` | `KBAPP_*` env + UserDefaults |
| `KnowledgeBaseAPIClientProtocol` | Sessions list + create session |
| `StubKnowledgeBaseAPIClient` + `InMemoryKBStore` | Demo session when no base URL |
| `URLSessionKnowledgeBaseAPIClient` | `GET/POST /api/sessions`, messages, attachments, files |
| `ChatAPIClientProtocol` | Messages + `streamTextMessage` / send + attachments (stub + `URLSession` same host) |
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
| `ChatAPIClientProtocol.sendVoiceRecording` | Stub + `POST /api/query/voice` (multipart: `audio`, `session_id`, `use_knowledge_base`, `transcription_hint`) |
| `VoiceRoutingContext` | Active chat session + KB toggle for voice send |
| `kbSessionThreadDidChange` | Voice send notifies open `ChatView` + session list to refetch |

## Next (product / backend)

- **Voice (remaining)** — multipart upload + Whisper-backed transcription text (KB App API + bot services).
- **Chat** — streaming assistant tokens from the server (SSE/WebSocket; see `docs/tasks/pending/task-feature-chat.md`).

## Backend boundary

Canonical HTTP contract for this app: **`docs/KB_APP_API_CONTRACT.md`** and **`docs/openapi/kb-app-api.yaml`**. Higher-level product notes remain in Nextcloud («Архитектура и бэкенд API»).

Until **KB App API** is implemented, the app uses the stub client. When the API is live, keep paths and JSON aligned with the repo contract in the same change as server updates.

Open choice for the repo layout (documented in Nextcloud tasks folder): separate `kb-app-api` service importing bot services vs. later merge into a gateway.

## Constraints (mandatory)

- Services expose protocols; dependencies are injected.
- New logic ships with tests (see `CODING_STANDARDS.md`).
