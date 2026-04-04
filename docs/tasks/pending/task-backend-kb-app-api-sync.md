# KB App API: contract sync (iOS ↔ server ↔ bot)

**Status:** Pending — server not in this repo; **knowledge-base-bot** owns shared business logic.

## Scope (this repo)

- Keep `URLSessionKnowledgeBaseAPIClient` paths and JSON decoding aligned with the spec in Nextcloud «Архитектура и бэкенд API» and `docs/tasks/pending/task-doc-api-client.md`.
- When the backend adds or changes endpoints, update models and tests here in the same PR or follow-up.

## Scope (backend / bot)

- Implementation belongs to **KB App API** task folder in Nextcloud and/or `knowledge-base-bot` (see `integration-notes.md` there).
- **Rules for Python work in `knowledge-base-bot`:** `.cursor/rules/development.md` — type hints, PEP 8, docstrings, logging, tests, error handling.

## First integration milestones (reference)

1. Same auth story as documented (Bearer / token endpoint if any).
2. Voice: multipart upload → Whisper → same session/message pipeline as text.
3. Files/changes: real `GET /api/files/changes` and `POST /api/files/revert` payloads.
