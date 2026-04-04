# KB App API — контракт (канон для iOS и бэкенда)

**Версия:** 1.0  
**Статус:** черновик для реализации FastAPI (`kb-app-api`) и клиента в этом репозитории.  
**Связь:** дополняет заметку в Nextcloud «Архитектура и бэкенд API» (папка `Документация`); при расхождении **пути и JSON для iOS** задаётся **здесь**, пока бэкенд не подтвердит OpenAPI.

## Базовые правила

| Правило | Значение |
|--------|-----------|
| База | HTTPS, префикс путей `/api` |
| Идентификаторы | Строки (`uuid` или строковый surrogate), в JSON — **строки**, не числа |
| Даты | ISO 8601 в UTC, поля `*_at` |
| JSON ключи | `snake_case` |
| Аутентификация | `Authorization: Bearer <token>` на всех маршрутах, кроме явно публичных (например `POST /api/auth/token`) |

## Ошибки

Для ответов **4xx / 5xx** тело по возможности:

```json
{
  "error": {
    "code": "validation_error",
    "message": "Human-readable summary",
    "detail": "Optional longer text or field hints"
  }
}
```

Клиент iOS читает `message`, затем `detail`, затем `code`. Если JSON не разобран — показывается превью тела ответа.

## Auth (опционально на ранней стадии)

| Метод | Путь | Описание |
|-------|------|----------|
| POST | `/api/auth/token` | Выдача токена (см. концепт в Nextcloud-доке). Пока допустим **только** статический токен из конфига без этого endpoint. |

## Сессии

| Метод | Путь | Запрос | Успех |
|-------|------|--------|--------|
| GET | `/api/sessions` | Query: `page`, `per_page` (опц.) | `200` — массив **или** объект с полями `sessions` \| `items` и опц. `total` |
| POST | `/api/sessions` | `{ "title": "..." }` | `200`/`201` — объект сессии **или** `{ "session": { ... } }` |

**Сессия (минимум для iOS):**

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "title": "Demo",
  "message_count": 0,
  "updated_at": "2026-04-05T12:00:00Z"
}
```

Расширения (игнорируются клиентом, если не нужны): `type`, `status`, `last_message_at`.

## Сообщения внутри сессии

История и отправка текста привязаны к **сессии** — это текущий контракт iOS-приложения (альтернатива «глобальному» `POST /api/query` из концепта).

| Метод | Путь | Запрос | Успех |
|-------|------|--------|--------|
| GET | `/api/sessions/{session_id}/messages` | Query: `page`, `per_page` | `200` — массив **или** `{ "messages": [...] }` \| `{ "items": [...] }` |
| POST | `/api/sessions/{session_id}/messages` | `{ "content": "...", "use_knowledge_base": true }` | `200`/`201` — `{ "messages": [...] }` или массив сообщений |

**Сообщение:**

```json
{
  "id": "msg-uuid",
  "role": "user",
  "content": "…",
  "created_at": "2026-04-05T12:00:00Z"
}
```

`role`: `user` \| `assistant` \| `system`.

### Стриминг ответа ассистента (следующий этап)

До готовности SSE/WebSocket клиент делает обычный `POST` и при необходимости имитирует набор текста локально. Целевой вариант:

- `Accept: text/event-stream` на том же `POST` **или** отдельный `GET`/`POST` stream-endpoint — фиксируется в OpenAPI при реализации.

## Вложения (файл в тред)

| Метод | Путь | Тело |
|-------|------|------|
| POST | `/api/sessions/{session_id}/attachments` | `multipart/form-data`: поле `file`, поле `use_knowledge_base` (`true`/`false`) |

Успех: как у `POST …/messages` — полный список сообщений или `messages` в JSON.

## Голос (Whisper + тот же пайплайн, что текст)

| Метод | Путь | Тело |
|-------|------|------|
| POST | `/api/query/voice` | `multipart/form-data`: `audio` (файл), `session_id`, `use_knowledge_base`, `transcription_hint` (опц.) |

Успех: как сообщения — массив / `{ "messages": [...] }` (плюс при необходимости поля `transcription` в теле — клиент может игнорировать, если тред уже обновлён).

## Изменённые файлы (рабочая копия KB)

| Метод | Путь | Запрос |
|-------|------|--------|
| GET | `/api/files/changes` | Query: `session_id` (опц.) |
| POST | `/api/files/revert` | `{ "file_id": "<id>" }` |

**Элемент списка:**

```json
{
  "id": "change-1",
  "path": "notes/x.md",
  "change_kind": "modified",
  "before_text": null,
  "after_text": "# …"
}
```

Примечание: в концепте встречается `POST /api/files/rollback` + `change_id` — при реализации бэкенда выбрать **одно** имя; iOS сейчас использует **`revert` + `file_id`**.

## Синхронизация (не в клиенте MVP)

`POST /api/sync/trigger`, `GET /api/sync/status` — по необходимости, см. Nextcloud-док.

## Артефакты в репозитории

- Машиночитаемый черновик: [`openapi/kb-app-api.yaml`](openapi/kb-app-api.yaml) (subset; расширять вместе с бэкендом).
