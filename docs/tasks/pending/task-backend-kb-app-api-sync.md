# KB App API: contract sync (iOS ↔ server ↔ bot)

**Status:** In progress — HTTP API lives in **`knowledge-base-bot/kb_app_api/`** (same business logic / DB as the bot). This repo stays aligned via contract + client.

## Scope (this repo)

- Keep `URLSessionKnowledgeBaseAPIClient` paths and JSON decoding aligned with **`docs/KB_APP_API_CONTRACT.md`** and `docs/openapi/kb-app-api.yaml`.
- When the backend adds or changes endpoints, update models, OpenAPI subset, and tests here in the same PR or follow-up.

## Scope (backend / bot)

- Implementation: **`knowledge-base-bot/kb_app_api/`**; task notes in Nextcloud «KB App API — бэкенд для iOS» (`todo.md`, `integration-notes.md`).
- **Rules for Python work in `knowledge-base-bot`:** `.cursor/rules/development.md` — type hints, PEP 8, docstrings, logging, tests, error handling.

## First integration milestones (reference)

1. Same auth story as documented (Bearer / token endpoint if any).
2. Voice: multipart upload → Whisper → same session/message pipeline as text.
3. Files/changes: real `GET /api/files/changes` and `POST /api/files/revert` payloads.
