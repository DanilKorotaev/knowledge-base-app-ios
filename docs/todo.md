# TODO

## In progress

_(none)_

## Planned

**Рекомендуемый порядок (2026-05):** 1) **деплой** KB App API на сервер и smoke/E2E — [чеклист в Nextcloud](../../Документация/Задачи/KB%20App%20API%20—%20бэкенд%20для%20iOS/Чеклист%20—%20деплой%20и%20интеграция.md); 2) интеграция iOS с **реальным SSE** и голосом ([task-feature-chat.md](tasks/pending/task-feature-chat.md), [task-feature-voice-input.md](tasks/pending/task-feature-voice-input.md)); 3) **TestFlight** ([task-ops-fastlane-testflight.md](tasks/pending/task-ops-fastlane-testflight.md)).

### Integration (против реального API)

- [ ] E2E: `KnowledgeBaseAPIE2ETests` против staging/prod — [docs/testing/E2E.md](testing/E2E.md)
- [ ] Ручной прогон: сессии, чат, SSE, вложения, голос, files/changes + revert
- [ ] Единый UX ошибок по контракту (`error.code`, `message`, `detail`)
- [ ] Dev/staging/prod: базовый URL и токен без секретов в git

### Product

- [x] [Voice MVP](tasks/completed/task-feature-voice-input-mvp.md) — запись + UI
- [x] [Чат: история + текст](tasks/completed/task-feature-chat-mvp.md) — HTTP-клиент готов
- [ ] [Голос: реальный upload + Whisper](tasks/pending/task-feature-voice-input.md) — после деплоя API
- [ ] [Чат: серверный SSE в бою](tasks/pending/task-feature-chat.md) — клиент шлёт `Accept: text/event-stream`
- [ ] [Чат: UX стриминга](tasks/pending/task-ux-chat-streaming-feedback.md) — прелоадер, typing dots, подмена на сообщение из БД
- [ ] [Push: ответ готов](tasks/pending/task-feature-push-notifications-chat.md) — APNs, deep link, suppress на открытом чате
- [ ] [Композер чата (Telegram UX)](tasks/pending/task-ux-chat-composer-telegram.md) — скрепка/sheet, микрофон→поле, превью, одна отправка (ждёт API compose)
- [ ] [Дефолтная сессия для голоса + TTL](tasks/pending/task-feature-default-voice-session.md) — маршрутизация с mic bar / widget / Watch
- [ ] [Удаление и переименование сессий](tasks/pending/task-feature-session-delete-rename.md) — UI + KB App API DELETE/PATCH
- [ ] [Чат: вложения, голос, Markdown/HTML](tasks/pending/task-ux-chat-rich-messages.md) — rich bubbles
- [ ] [Apple Watch: companion + complication](tasks/pending/task-feature-watch-app-voice.md) — запись с циферблата

### Backend (`knowledge-base-bot/kb_app_api/`)

- [x] [KB App API MVP](tasks/completed/task-backend-kb-app-api-mvp.md) — эндпоинты по контракту
- [ ] [Синхронизация контракта при изменениях](tasks/pending/task-backend-kb-app-api-sync.md) — ongoing

### Ops / CI

- [ ] [Match + ASC + TestFlight](tasks/pending/task-ops-fastlane-testflight.md)
- [x] [MIT LICENSE](tasks/completed/task-sessions-attachments-license.md)

### Documentation

- [x] [Контракт KB App API в репо](tasks/completed/task-doc-kb-app-api-contract.md)
- [x] Чеклист деплоя и интеграции (Nextcloud)

## Completed

See [completed.md](completed.md).
