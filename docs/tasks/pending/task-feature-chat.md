# Chat: text send + history

**Status:** Клиент стримит ответ ассистента (stub — по словам; HTTP — `POST …/messages` с `Accept: text/event-stream` → SSE `delta`, иначе JSON и чанки по словам).

## Done

- `ChatAPIClientProtocol`, stub с демо-сессией, `URLSession` для messages.
- Экран чата, переключатель use KB, пузырьки user/assistant.
- `streamTextMessage` + рост пузыря ассистента в UI; `use_knowledge_base` в теле запроса.
- `URLSessionKnowledgeBaseAPIClient.streamTextMessage`: **`bytes(for:)`**, SSE `data:` + `ChatSSEEvent`, fallback на JSON.

## Remaining

- Режимы «с БЗ» / «пустой чат» на стороне сервера (клиент уже шлёт флаг).
- При необходимости — донастройка UX, если pre-fetch треда и SSE-ответ на одном `POST` дают гонку (сервер должен сохранять user-сообщение до первого чанка SSE).

## Done (client prep)

- `SSEventParser` / `StreamBuffer` — разбор SSE `data:` ([KB_APP_API_CONTRACT.md](../KB_APP_API_CONTRACT.md) § стриминг).
