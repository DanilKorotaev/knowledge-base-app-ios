# TODO

## In progress

_(none)_

## Planned

**Рекомендуемый порядок (2026-06):** 1) **E2E automation** — расширить `KnowledgeBaseAPIE2ETests` ([task-backend-kb-app-api-sync.md](tasks/pending/task-backend-kb-app-api-sync.md)); 2) **Push notifications** ([task-feature-push-notifications-chat.md](tasks/pending/task-feature-push-notifications-chat.md)); 3) **Apple Watch** ([task-feature-watch-app-voice.md](tasks/pending/task-feature-watch-app-voice.md)).

### Integration (E2E + contract)

- [ ] E2E: расширить `KnowledgeBaseAPIE2ETests` — SSE, voice, compose — [docs/testing/E2E.md](testing/E2E.md)
- [ ] Ручной прогон: сессии, чат, SSE, вложения, голос, files/changes + revert
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
- [ ] [Push: ответ готов](tasks/pending/task-feature-push-notifications-chat.md) — APNs, deep link, suppress на открытом чате
- [ ] [Apple Watch: companion + complication](tasks/pending/task-feature-watch-app-voice.md) — запись с циферблата

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
