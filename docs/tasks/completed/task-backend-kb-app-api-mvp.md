# KB App API (FastAPI): этапы MVP

**Status:** Done (2026) — реализация в `knowledge-base-bot/kb_app_api/`.

## Delivered

По **`docs/KB_APP_API_CONTRACT.md`**:

1. **Auth (опционально)** — Bearer из env; `POST /api/auth/token` при `KB_APP_API_TOKEN_ENDPOINT_ENABLED`.
2. **Сессии** — `GET/POST /api/sessions`.
3. **Сообщения** — `GET/POST /api/sessions/{id}/messages`, `use_knowledge_base`, вложения.
4. **Голос** — `POST /api/query/voice` (multipart) → Whisper + `QueryProcessingService`.
5. **Файлы** — `GET /api/files/changes`, `POST /api/files/revert` (`file_id`).
6. **Стриминг** — SSE при `Accept: text/event-stream`.

Docker: `kb-app-api/Dockerfile`, сервисы в `docker-compose.yml` / `docker-compose.prod.yml`.

## Next (не код MVP)

- Деплой на сервер, smoke, E2E iOS — [чеклист Nextcloud](../../../../Документация/Задачи/KB%20App%20API%20—%20бэкенд%20для%20iOS/Чеклист%20—%20деплой%20и%20интеграция.md).
- Поддержка контракта при изменениях — [task-backend-kb-app-api-sync.md](../pending/task-backend-kb-app-api-sync.md).

## See also

- Bot: `knowledge-base-bot/docs/tasks/pending/task-kb-app-api-mvp.md`
- Nextcloud: `Документация/Задачи/KB App API — бэкенд для iOS/todo.md`
