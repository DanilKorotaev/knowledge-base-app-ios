# KB App API: contract sync (iOS ↔ server ↔ bot)

**Status:** Backend implemented in **`knowledge-base-bot/kb_app_api/`**; OpenAPI subset updated in **`docs/openapi/kb-app-api.yaml`**. Keep client aligned on changes.

## Scope (this repo)

- Keep `URLSessionKnowledgeBaseAPIClient` paths and JSON decoding aligned with **`docs/KB_APP_API_CONTRACT.md`** and **`docs/openapi/kb-app-api.yaml`**.
- When the backend adds or changes endpoints, update models, OpenAPI, and tests here in the same PR or follow-up.

## Scope (backend / bot)

- Implementation: **`knowledge-base-bot/kb_app_api/`**; setup notes in Nextcloud «KB App API — бэкенд для iOS».
- Smoke tests: `python -m unittest kb_app_api.tests.test_smoke` (requires bot `requirements.txt`).
- **Rules for Python:** `.cursor/rules/development.md` in `knowledge-base-bot`.

## Server-side reminders

- **`ACCESS_MODE=restricted`**: API user (`KB_APP_API_TELEGRAM_ID`) must have `is_allowed=true`, or set **`KB_APP_API_BYPASS_ACCESS_CHECK=true`** only for debugging (see bot `config` and `kb_app_api/deps.py`).

## First integration milestones (reference)

1. Bearer and optional `POST /api/auth/token`.
2. Voice, files, attachments — match contract.
3. E2E from device against staging HTTPS URL.
