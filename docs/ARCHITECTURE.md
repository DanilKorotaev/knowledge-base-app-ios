# Architecture

## Goal

Alternative **iOS client** to the same knowledge base infrastructure as the Telegram bot:

- Shared **PostgreSQL** (sessions, messages) — once KB App API exists.
- Same **Cursor CLI** / processing services on the server.
- **Nextcloud WebDAV** and **Whisper** transcription remain server-side concerns.

The app talks only to **HTTPS APIs**; it does not run Cursor or touch the database directly.

## Current skeleton

| Area | Status |
|------|--------|
| SwiftUI shell (`MainView`, `SettingsView`) | Initial |
| `AppConfiguration` | `KBAPP_*` env + UserDefaults |
| `KnowledgeBaseAPIClientProtocol` | Sessions list |
| `StubKnowledgeBaseAPIClient` + `InMemoryKBStore` | Demo session when no base URL |
| `URLSessionKnowledgeBaseAPIClient` | `GET /api/sessions` |
| `ChatAPIClientProtocol` | Messages + send text (stub + `URLSession` same host) |
| `ChatView` / `ChatViewModel` | Thread + composer |
| `KBSession`, `KBMessage` | REST-oriented models |

## Voice (partial)

| Piece | Status |
|-------|--------|
| `VoiceRecordingService` | AAC to temp file, metering |
| `VoiceRecordingViewModel` + `MicRecordControl` | Hold / cancel / lock, review sheet |
| `VoiceUploadClientProtocol` | Stub only; real HTTP when KB App API exists |

## Planned modules (from product plan)

- **Voice (remaining)** — multipart upload + Whisper-backed transcription text.
- **Chat** — message list, text input, attachments.
- **Files** — changed files / diff via API.
- **Widgets** — WidgetKit + App Intents.

## Backend boundary

Until **KB App API** is implemented, the app uses the stub client. When the API is live, align URL paths and JSON with the spec in the knowledge base document «Архитектура и бэкенд API».

Open choice for the repo layout (documented in Nextcloud tasks folder): separate `kb-app-api` service importing bot services vs. later merge into a gateway.

## Constraints (mandatory)

- Services expose protocols; dependencies are injected.
- New logic ships with tests (see `CODING_STANDARDS.md`).
