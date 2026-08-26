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
| `task-ux-cursor-activity-streaming.md` | Cursor tool activity label during long SSE replies |
| `task-feature-offline-cache-foundation.md` | File-backed offline cache for sessions/messages |
| `task-ux-swr-sync-status-sessions-chat.md` | SWR sync status banners on list and chat |
| `task-feature-offline-attachment-disk-cache-management.md` | Attachment disk cache + Settings management |
| `task-feature-offline-mode-cache-sync.md` | Offline mode epic (v1) |

## Pending (`pending/`)

| File | Topic | Статус (2026-06-20) |
|------|--------|---------------------|
| `task-backend-kb-app-api-sync.md` | Contract alignment + E2E automation | 🟡 ongoing |
| `task-feature-push-notifications-chat.md` | APNs when reply ready | 🟡 MVP в коде, E2E на устройстве |
| `task-feature-watch-app-voice.md` | watchOS companion, complication | 🟡 relay + deep link готовы; **нет WidgetKit complication** |
| `task-ux-chat-clickable-changed-files.md` | Chat: clickable changed files (MVP → inline) | бэклог |
| `task-ux-chat-composer-polish.md` | Quick Look, лимиты, RU | бэклог |
| `task-feature-voice-recording-pause-resume-locked.md` | Voice: pause/resume in LOCKED mode | бэклог |
| `task-ux-voice-transcription-retry-without-loss.md` | Voice: inline retry on transcription/send errors | completed 2026-07-03 |
| `task-ux-session-kb-mode-persistent.md` | Move `Use Knowledge Base` to session creation | бэклог |
| `task-ux-chat-resume-streaming-after-background.md` | Resume streaming UI after background / leave chat | completed |
| `task-ux-chat-error-retry-instead-of-draft-restore.md` | Error/timeout: Retry on bubble, don’t refill composer | code done |
| `task-ux-chat-copy-message.md` | Copy entire message + optional copy sheet | code done |
| `task-bug-chat-empty-message-bubble.md` | Empty bubble (space without content) | бэклог |
| `task-bug-composer-send-voice-attachments-failure.md` | Voice/photo send fail (draft files cleared too early) | partially fixed |
| `task-feature-api-client-version-metadata.md` | API client version headers for debugging | бэклог |
| `task-feature-structured-ui-mvp.md` | Structured UI MVP | бэклог |
| `task-ops-semver-versioning-changelog-gitflow.md` | SemVer + changelog + git-flow | бэклог |

**Deploy / E2E checklist (Nextcloud):** `Документация/Задачи/KB App API — бэкенд для iOS/Чеклист — деплой и интеграция.md`
