# Feature: Structured UI MVP (JSON screen in chat)

**Status:** In progress (feature branch `feature/structured-ui-mvp`)  
**Priority:** High  
**Related (bot):** `knowledge-base-bot/docs/tasks/pending/task-feature-structured-ui-mvp.md`

## Goal

Render assistant `structured_ui` in chat, send button taps via `POST /api/sessions/{id}/ui-events`, replace panel from server response.

## Scope (MVP-10…12)

- [x] Decodable models (`schema_version`, `screen` tree)
- [x] SwiftUI renderer (`vstack`, `text`, `button`)
- [x] `structured_ui` on `KBMessage`
- [x] API client `sendUIEvent`
- [x] Chat panel + toolbar entry «Interactive UI» (mock bootstrap `action_id: start`)
- [x] Unit tests (decode + ViewModel)
- [x] Unsupported `schema_version` banner (no crash)
- [x] L10n EN/RU for toolbar and panel strings
- [x] OpenAPI + contract (`docs/openapi/kb-app-api.yaml`, `KB_APP_API_CONTRACT.md`)

## Deploy

Separate feature branch from `main`. Backend mock must be deployed first for real-device E2E.

## Acceptance

- [x] XCTest green for structured UI models / ViewModel (после rebase на main)
- [ ] Manual E2E against deployed API: start → Yes/No → Done  
  Чеклист: Obsidian «Structured UI — план ручного теста»
