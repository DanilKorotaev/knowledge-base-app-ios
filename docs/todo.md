# TODO

## In progress

- [ ] [Push: ответ готов](tasks/pending/task-feature-push-notifications-chat.md) — MVP в коде; приёмка E2E на устройстве
- [ ] [Apple Watch: complication](tasks/pending/task-feature-watch-app-voice.md) — relay готов, нет виджета на циферблате

## Planned

**Recommended order (2026-06-19):** 1) **Attachment disk cache**; 2) **Push E2E**; 3) **Clickable changed files**; 4) E2E automation; 5) Watch complication; 6) Composer polish.

### Integration (E2E + contract)

- [ ] E2E: расширить `KnowledgeBaseAPIE2ETests` — SSE delta, voice, compose — [docs/testing/E2E.md](testing/E2E.md)
- [ ] Ручной прогон: сессии, чат, SSE, вложения, голос, files/changes + revert, **пагинация чата** (90+ сообщений)
- [ ] Единый UX ошибок по контракту (`error.code`, `message`, `detail`)
- [ ] [Синхронизация контракта при изменениях](tasks/pending/task-backend-kb-app-api-sync.md) — ongoing

### Product

- [x] [Voice MVP](tasks/completed/task-feature-voice-input-mvp.md) — запись + UI
- [x] [Голос: prod pipeline + Whisper](tasks/completed/task-feature-voice-input.md) — completed 2026-06-10
- [x] [Чат: история + текст (MVP)](tasks/completed/task-feature-chat-mvp.md) — HTTP-клиент
- [x] [Чат: SSE в бою](tasks/completed/task-feature-chat.md) — completed 2026-06-10
- [x] [Чат: UX стриминга](tasks/completed/task-ux-chat-streaming-feedback.md) — completed 2026-06-09
- [x] [Композер чата (Telegram UX)](tasks/completed/task-ux-chat-composer-telegram.md) — completed 2026-06-09
- [x] [Дефолтная сессия для голоса + TTL](tasks/completed/task-feature-default-voice-session.md) — completed 2026-06-09
- [x] [Удаление и переименование сессий](tasks/completed/task-feature-session-delete-rename.md) — completed 2026-06-01
- [x] [Чат: вложения, голос, Markdown/HTML](tasks/completed/task-ux-chat-rich-messages.md) — completed 2026-06-01
- [x] [Чат: markdown blocks + `---`](tasks/completed/task-ux-chat-markdown-blocks.md) — completed 2026-06-18
- [x] [Чат: пагинация (load older)](tasks/completed/task-feature-chat.md) — fix `d49bbe7` 2026-06-18
- [ ] [Push: ответ готов](tasks/pending/task-feature-push-notifications-chat.md) — см. In progress
- [ ] [Apple Watch: complication](tasks/pending/task-feature-watch-app-voice.md) — см. In progress
- [x] [Оффлайн-режим v1](tasks/completed/task-feature-offline-mode-cache-sync.md) — cache-first, SWR, attachment disk cache
- [x] [Offline foundation: persistent cache](tasks/completed/task-feature-offline-cache-foundation.md) — `FileOfflineCacheStore`, cache-first list/chat
- [x] [SWR sync UX: статусы обновления](tasks/completed/task-ux-swr-sync-status-sessions-chat.md) — refreshing/offline/error для списка и чата
- [x] [Offline attachments: disk cache management](tasks/completed/task-feature-offline-attachment-disk-cache-management.md) — размер, список, выборочное удаление
- [ ] [Чат: кликабельные changed files](tasks/pending/task-ux-chat-clickable-changed-files.md) — MVP список под ответом, затем inline-ссылки
- [ ] [Композер: polish](tasks/pending/task-ux-chat-composer-polish.md) — Quick Look, лимиты, RU

### Backend (`knowledge-base-bot/kb_app_api/`)

- [x] [KB App API MVP](tasks/completed/task-backend-kb-app-api-mvp.md) — эндпоинты по контракту

### Ops / CI

- [x] [Match + ASC + TestFlight](tasks/completed/task-ops-fastlane-testflight.md) — CI/CD deploy, completed 2026-06-10
- [x] [MIT LICENSE](tasks/completed/task-sessions-attachments-license.md)

### Documentation

- [x] [Контракт KB App API в репо](tasks/completed/task-doc-kb-app-api-contract.md)
- [x] Чеклист деплоя и интеграции (Nextcloud)

## Completed

See [completed.md](completed.md).
