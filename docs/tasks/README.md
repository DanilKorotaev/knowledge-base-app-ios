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
| `task-ops-fastlane-testflight.md` | Match, ASC, TestFlight via CI/CD |
| `task-feature-voice-input-mvp.md` | Voice UI + stub upload |
| `task-feature-voice-input.md` | Prod voice + Whisper + composer routing |
| `task-feature-chat-mvp.md` | Chat stub + HTTP shapes |
| `task-feature-chat.md` | SSE streaming + prod integration |
| `task-sessions-attachments-license.md` | Sessions, attachments, MIT |
| `task-files-diff-widgets-camera.md` | Changed files, diff, widgets, camera, deep link |
| `task-feature-widgets-app-intents.md` | App Intents, Shortcuts, widget mic button |
| `task-doc-kb-app-api-contract.md` | KB App API contract + OpenAPI subset + error parsing |
| `task-backend-kb-app-api-mvp.md` | FastAPI MVP in `knowledge-base-bot/kb_app_api/` |
| `task-ux-chat-rich-messages.md` | Attachments, voice playback, Markdown/HTML bubbles |
| `task-ux-chat-markdown-blocks.md` | Lists, fenced code, blockquotes in assistant markdown |
| `task-feature-session-delete-rename.md` | Delete/rename sessions in UI |
| `task-ux-chat-streaming-feedback.md` | Processing spinner, typing dots, stream → final message |
| `task-ux-chat-composer-telegram.md` | Telegram-style composer, compose API, draft attachments |
| `task-feature-default-voice-session.md` | Default voice target session + optional TTL |
| `task-feature-pinned-sessions.md` | Pin sessions to top of list (local UserDefaults) |

## Pending (`pending/`)

| File | Topic |
|------|--------|
| `task-backend-kb-app-api-sync.md` | Contract alignment + E2E automation (SSE, voice, compose) |
| `task-feature-push-notifications-chat.md` | APNs when reply ready (background / other screen) |
| `task-feature-watch-app-voice.md` | watchOS companion, complication, offline queue |

**Deploy / E2E checklist (Nextcloud):** `Документация/Задачи/KB App API — бэкенд для iOS/Чеклист — деплой и интеграция.md`
