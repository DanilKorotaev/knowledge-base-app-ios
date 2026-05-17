# Task index (iOS)

**Product plan (canonical):** knowledge base note «План реализации iOS-приложения базы знаний» in Nextcloud.

**Backend (KB App API, FastAPI):** tasks and contract notes live in Nextcloud  
`Документация/Задачи/KB App API — бэкенд для iOS/` (see `todo.md`, `integration-notes.md`).  
When implementing shared services in **`knowledge-base-bot`**, follow that repo’s `.cursor/rules/` (PEP 8, type hints, logging, tests).

## Completed (`completed/`)

| File | Topic |
|------|--------|
| `task-skeleton-repo-ci.md` | XcodeGen, CI |
| `task-fastlane-setup.md` | Fastlane |
| `task-feature-voice-input-mvp.md` | Voice UI + stub upload |
| `task-feature-chat-mvp.md` | Chat stub + HTTP shapes |
| `task-sessions-attachments-license.md` | Sessions, attachments, MIT |
| `task-files-diff-widgets-camera.md` | Changed files, diff, widgets, camera, deep link |
| `task-feature-widgets-app-intents.md` | App Intents, Shortcuts, widget mic button |
| `task-doc-kb-app-api-contract.md` | KB App API contract + OpenAPI subset + error parsing |
| `task-backend-kb-app-api-mvp.md` | FastAPI MVP in `knowledge-base-bot/kb_app_api/` |

## Pending (`pending/`)

| File | Topic |
|------|--------|
| `task-feature-voice-input.md` | Real voice E2E against deployed API (Whisper on server) |
| `task-feature-chat.md` | Server SSE verified in production |
| `task-backend-kb-app-api-sync.md` | Ongoing contract alignment iOS ↔ KB App API ↔ bot |
| `task-ops-fastlane-testflight.md` | Match, ASC, TestFlight |

**Deploy / E2E checklist (Nextcloud):** `Документация/Задачи/KB App API — бэкенд для iOS/Чеклист — деплой и интеграция.md`
