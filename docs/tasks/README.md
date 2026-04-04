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

## Pending (`pending/`)

| File | Topic |
|------|--------|
| `task-feature-voice-input.md` | Real audio upload + Whisper when API exists |
| `task-feature-chat.md` | Streaming assistant replies (SSE/WS TBD) |
| `task-backend-kb-app-api-mvp.md` | FastAPI phases (sessions → messages → voice → files → stream) |
| `task-backend-kb-app-api-sync.md` | Contract alignment iOS ↔ KB App API ↔ bot services (voice: `task-api-kb-app-voice-query-ios.md` в репо бота) |
| `task-ops-fastlane-testflight.md` | Match, ASC, TestFlight |
