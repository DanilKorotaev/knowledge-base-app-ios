# KB App API — контракт (канон для iOS и бэкенда)

**Версия:** 1.1  
**Статус:** prod — реализация в `knowledge-base-bot/kb_app_api/`, клиент iOS на `https://kbapp.coredan.ru` (и staging).  
**OpenAPI subset:** [`openapi/kb-app-api.yaml`](openapi/kb-app-api.yaml) — держать в синке с этим файлом.

**Связь:** дополняет заметку в Nextcloud «Архитектура и бэкенд API»; при расхождении **пути и JSON для iOS** задаются **здесь**.

## Базовые правила

| Правило | Значение |
|--------|-----------|
| База | HTTPS, префикс путей `/api` |
| Идентификаторы | Строки (`uuid` или строковый surrogate), в JSON — **строки**, не числа |
| Даты | ISO 8601 в UTC, поля `*_at` |
| JSON ключи | `snake_case` |
| Аутентификация | `Authorization: Bearer <token>` на всех маршрутах, кроме явно публичных (`GET /health`, опционально `POST /api/auth/token`) |
| E2E-тесты | Заголовок `X-KB-App-E2E: 1` — отдельный telegram user на сервере (см. `docs/testing/E2E.md`) |
| Клиент (iOS, optional) | `X-KB-App-Version`, `X-KB-App-Build`, `X-KB-App-Platform` (`ios`), `X-KB-App-OS`, `X-KB-App-Log-Session` (on-device log file session UUID); также `User-Agent: KnowledgeBaseApp/<ver> (ios <os>; build <n>)`. Сервер логирует в `request.state.client_meta`, не требует для авторизации. |

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

## Auth (опционально)

| Метод | Путь | Описание |
|-------|------|----------|
| POST | `/api/auth/token` | Выдача Bearer при `KB_APP_API_TOKEN_ENDPOINT_ENABLED=true`. Иначе **404**. |

## Сессии

| Метод | Путь | Запрос | Успех |
|-------|------|--------|--------|
| GET | `/api/sessions` | Query: `page`, `per_page` (default 20, max 100; iOS обходит страницы с `per_page=100`) | `200` — `{ "sessions", "total", "page", "per_page" }` |
| GET | `/api/sessions/search` | Query: `q` (ID или текст в title/сообщениях) | `200` — `{ "sessions", "total" }` |
| POST | `/api/sessions` | `{ "title": "..." }` (опц., default «Новый чат») | `201` — `{ "session": { ... } }` |
| PATCH | `/api/sessions/{session_id}` | `{ "title": "..." }` (1…500 после trim) | `200` — `{ "session": { ... } }` |
| DELETE | `/api/sessions/{session_id}` | — | `200` — `{ "success": true }` (soft delete) |

**Сессия (минимум для iOS):**

```json
{
  "id": "109",
  "title": "Demo",
  "message_count": 42,
  "updated_at": "2026-04-05T12:00:00Z"
}
```

Расширения (игнорируются клиентом): `type`, `status`, `last_message_at`.

## Сообщения внутри сессии

| Метод | Путь | Запрос | Успех |
|-------|------|--------|--------|
| GET | `/api/sessions/{session_id}/messages` | Query: `limit` (>= 1, default 20), опц. `before` (id сообщения) | `200` — `{ "messages", "total", "has_more_older" }` |
| POST | `/api/sessions/{session_id}/messages` | JSON: `{ "content", "use_knowledge_base" }` | `201` JSON или SSE (см. ниже) |

**Пагинация GET:** без `before` — последние `limit` сообщений (хронологический порядок); с `before={message_id}` — ещё `limit` сообщений **старше** указанного id.

**Сообщение:**

```json
{
  "id": "msg-uuid",
  "role": "user",
  "content": "…",
  "content_format": "plain",
  "created_at": "2026-04-05T12:00:00Z",
  "attachments": [
    {
      "id": "7",
      "file_type": "photo",
      "file_name": "pic.jpg",
      "file_size": 12345,
      "mime_type": "image/jpeg",
      "download_url": "/api/sessions/{session_id}/attachments/7/file"
    }
  ],
  "transcription": null
}
```

`content_format`: `markdown` | `html` | `plain`.

Для `file_type=voice` в `attachments[]` допускается `transcription`; на уровне сообщения — `transcription` (voice-only).

### Стриминг ответа ассистента (SSE)

Заголовок клиента:

`Accept: text/event-stream, application/json;q=0.9`

Применяется к:

- `POST …/messages`
- `POST …/messages/voice`
- `POST …/messages/compose`

Ответ **`Content-Type: text/event-stream`**. Каждое событие — строка `data:` + JSON (`ChatSSEEvent` / `SSEventParser`):

| Событие | Когда |
|---------|--------|
| `{"status":"processing"}` | Сразу после POST — сброс буферов nginx/клиента до старта Cursor/KB |
| `{"activity":"tool","label":"…"}` | Прогресс Cursor CLI (чтение файла, shell и т.д.) до первого `delta` |
| `{"delta":"…"}` | Чанк текста ассистента (может быть разбит сервером ~48 символов) |
| `{"error":"…"}` | Ошибка пайплайна (поток может завершиться `done`) |
| `{"done":true}` | Нормальное завершение |

Без `Accept: text/event-stream` — синхронный JSON `{ "messages": [...] }` (HTTP 201). iOS fallback: разбивает финальный текст ассистента по словам для UX.

Timeout клиента на SSE: **600 s** (Cursor + sync могут занимать минуты до первого `delta`).

### Compose (Telegram-style composer)

| Метод | Путь | Тело |
|-------|------|------|
| POST | `/api/sessions/{session_id}/messages/compose` | `multipart/form-data` |

Поля:

| Поле | Обязательность | Описание |
|------|----------------|----------|
| `content` | опц. | Текст сообщения |
| `use_knowledge_base` | опц., default `true` | Form-boolean string |
| `files` | опц., repeat | Файлы/фото (несколько частей с именем `files`) |
| `audio` | опц., repeat | Голосовые клипы (несколько частей с именем `audio`) |
| `audio_transcriptions` | опц. | JSON-массив строк — по одной на каждый `audio`, **в том же порядке** |

Хотя бы одно из `content` (непустой после trim), `files`, `audio` обязательно.

Успех: JSON `{ "messages": [...] }` или SSE (как у текста). iOS: `streamComposedMessage` в `URLSessionKnowledgeBaseAPIClient`.

## Вложения

| Метод | Путь | Тело |
|-------|------|------|
| POST | `/api/sessions/{session_id}/attachments` | `multipart`: `file`, `use_knowledge_base`, опц. `message` (текст запроса) |
| GET | `/api/sessions/{session_id}/attachments/{attachment_id}/file` | — (Bearer, бинарный ответ) |

Успех POST: `{ "messages": [...] }`.

## Голос

### Только транскрибация

| Метод | Путь | Тело |
|-------|------|------|
| POST | `/api/query/voice/transcribe` | `multipart`: `audio` |

Успех: `{ "transcription": "…" }`.

### Транскрипция + ответ в тред (основной iOS-путь)

| Метод | Путь | Тело |
|-------|------|------|
| POST | `/api/sessions/{session_id}/messages/voice` | `multipart`: `audio`, `content` (непустая транскрипция), `use_knowledge_base` |

Успех: JSON или SSE. Сервер сохраняет voice attachment + transcription в БД.

**iOS flow:** `transcribe` → правка в composer → `messages/voice` или `compose` (несколько клипов).

### Legacy one-shot

| Метод | Путь | Тело |
|-------|------|------|
| POST | `/api/query/voice` | `multipart`: **`session_id`** (обяз.), `audio` **или** `transcription_hint`, `use_knowledge_base` |

Успех: `{ "messages": [...], "transcription": "…" }`. Клиент сохраняет метод `sendVoiceRecording`; основной UX использует пути выше.

## Изменённые файлы (рабочая копия KB)

| Метод | Путь | Запрос |
|-------|------|--------|
| GET | `/api/files/changes` | Query: `session_id` (опц.) |
| POST | `/api/files/revert` | `{ "file_id": "<id из changes>" }` |

**Элемент списка:**

```json
{
  "id": "change-1",
  "path": "notes/x.md",
  "change_kind": "modified",
  "before_text": null,
  "after_text": "# …",
  "created_at": "2026-04-05T12:00:00Z"
}
```

Ответ revert: `{ "ok": true, "change_id": "…", "path": "…" }`.

## Синхронизация (не в клиенте MVP)

`POST /api/sync/trigger`, `GET /api/sync/status` — по необходимости, см. Nextcloud-док.

## Артефакты в репозитории

- OpenAPI: [`openapi/kb-app-api.yaml`](openapi/kb-app-api.yaml)
- Ongoing sync + E2E roadmap: [`tasks/pending/task-backend-kb-app-api-sync.md`](tasks/pending/task-backend-kb-app-api-sync.md)
