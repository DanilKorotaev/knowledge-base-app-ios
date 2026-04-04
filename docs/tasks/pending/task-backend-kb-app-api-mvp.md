# KB App API (FastAPI): этапы MVP

**Status:** Pending — реализация вне этого репозитория (`kb-app-api` + сервисы из `knowledge-base-bot`).

## Контракт

Реализовать HTTP-поведение по **`docs/KB_APP_API_CONTRACT.md`** и расширять **`docs/openapi/kb-app-api.yaml`**.

## Фазы

1. **Auth (опционально)** — статический Bearer из env; при необходимости `POST /api/auth/token`.
2. **Сессии** — `GET/POST /api/sessions` с идентификаторами-строками и пагинацией.
3. **Сообщения** — `GET/POST /api/sessions/{id}/messages` с `use_knowledge_base`.
4. **Голос** — `POST /api/query/voice` (multipart), пайплайн Whisper → тот же обработчик, что текст.
5. **Файлы** — `GET /api/files/changes`, `POST /api/files/revert` с телом `{ "file_id" }`.
6. **Стриминг** — SSE/WebSocket после стабилизации синхронного пути (см. `task-feature-chat.md`).

## Правила

Python в боте: `.cursor/rules/` репозитория `knowledge-base-bot`.
