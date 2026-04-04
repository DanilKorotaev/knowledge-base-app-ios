# TODO

## In progress

_(none)_

## Planned

**Рекомендуемый порядок:** 1) поднять **KB App API** по [task-backend-kb-app-api-mvp.md](tasks/pending/task-backend-kb-app-api-mvp.md) (сессии → сообщения → голос → файлы → SSE); 2) в iOS переключить чат на **реальный SSE** поверх `SSEventParser` ([task-feature-chat.md](tasks/pending/task-feature-chat.md)); 3) **TestFlight** ([task-ops-fastlane-testflight.md](tasks/pending/task-ops-fastlane-testflight.md)) параллельно или после стабильного API.

### Product

- [x] [Voice MVP](tasks/pending/task-feature-voice-input.md) — см. [completed](tasks/completed/task-feature-voice-input-mvp.md); Whisper/upload — когда будет API
- [x] [Чат: история + текст](tasks/pending/task-feature-chat.md) — см. [completed](tasks/completed/task-feature-chat-mvp.md); стриминг ответа — позже
- [ ] [Голос: реальный upload](tasks/pending/task-feature-voice-input.md) — после KB App API
- [ ] [Чат: серверный SSE на FastAPI](tasks/pending/task-feature-chat.md) — клиент уже шлёт `Accept: text/event-stream` и парсит `delta`/`done`

### Backend (вне репо)

- [ ] [KB App API MVP (FastAPI)](tasks/pending/task-backend-kb-app-api-mvp.md) — по [KB_APP_API_CONTRACT.md](KB_APP_API_CONTRACT.md)
- [ ] [Синхронизация контракта](tasks/pending/task-backend-kb-app-api-sync.md)

### Ops / CI _(отложено — код и фичи в приоритете)_

- [ ] [Match + ASC + TestFlight](tasks/pending/task-ops-fastlane-testflight.md)
- [x] [MIT LICENSE](tasks/completed/task-sessions-attachments-license.md) _(was task-doc-license)_

### Documentation

- [x] [Контракт KB App API в репо](tasks/completed/task-doc-kb-app-api-contract.md)

## Completed

See [completed.md](completed.md).
