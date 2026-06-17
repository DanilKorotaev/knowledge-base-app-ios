# KB App API: contract sync + E2E automation (iOS ↔ server ↔ bot)

**Status:** Ongoing — backend in **`knowledge-base-bot/kb_app_api/`** (MVP done); OpenAPI subset in **`docs/openapi/kb-app-api.yaml`**. Keep client aligned on changes.

Deploy checklist (Nextcloud): [Чеклист — деплой и интеграция.md](../../../../Документация/Задачи/KB%20App%20API%20—%20бэкенд%20для%20iOS/Чеклист%20—%20деплой%20и%20интеграция.md).

## Scope (this repo)

- Keep `URLSessionKnowledgeBaseAPIClient` paths and JSON decoding aligned with **`docs/KB_APP_API_CONTRACT.md`** (v1.1) and **`docs/openapi/kb-app-api.yaml`** (v1.1).
- When the backend adds or changes endpoints, update models, OpenAPI, contract, and tests in the same PR or follow-up.

## E2E automation (remaining)

Current `KnowledgeBaseAPIE2ETests` covers `GET /health`, session CRUD smoke, and `POST …/messages` (text, `use_knowledge_base: false`). See [docs/testing/E2E.md](../../testing/E2E.md).

- [x] OpenAPI + contract v1.1 — compose, search, messages pagination, SSE events, files/changes schema (2026-06-10)
- [ ] SSE: `streamTextMessage` — assert at least one `delta` event (or `processing` → `done`).
- [ ] Voice: `transcribeVoiceRecording` against prod/staging fixture audio.
- [ ] Compose: `streamComposedMessage` — text + small attachment smoke.
- [ ] Session delete/rename round-trip in E2E suite.
- [ ] Unified error UX in app for `error.code` / `message` / `detail` from API.
- [ ] Manual UI regression checklist: sessions, chat, SSE, attachments, voice, files/changes + revert (device + TestFlight build).

## Scope (backend / bot)

- Implementation: **`knowledge-base-bot/kb_app_api/`**; setup notes in Nextcloud «KB App API — бэкенд для iOS».
- Smoke tests: `python -m unittest kb_app_api.tests.test_smoke` (requires bot `requirements.txt`).
- **Rules for Python:** `.cursor/rules/development.md` in `knowledge-base-bot`.

## Server-side reminders

- **`ACCESS_MODE=restricted`**: API user (`KB_APP_API_TELEGRAM_ID`) must have `is_allowed=true`, or set **`KB_APP_API_BYPASS_ACCESS_CHECK=true`** only for debugging (see bot `config` and `kb_app_api/deps.py`).

## Backend backlog (performance / architecture)

- [task-api-background-query-jobs.md](../../../knowledge-base-bot/docs/tasks/pending/task-api-background-query-jobs.md) — вынести Cursor/sync в фоновые jobs (не зависеть от числа uvicorn workers).
- [task-api-sessions-list-performance.md](../../../knowledge-base-bot/docs/tasks/pending/task-api-sessions-list-performance.md) — `message_count` без загрузки всех сообщений.
