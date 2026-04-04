# Chat: text send + history

**Status:** Клиент стримит ответ ассистента (stub — по словам; HTTP — после `POST …/messages` чанками из полного текста до появления SSE).

## Done

- `ChatAPIClientProtocol`, stub с демо-сессией, `URLSession` для messages.
- Экран чата, переключатель use KB, пузырьки user/assistant.
- `streamTextMessage` + рост пузыря ассистента в UI; `use_knowledge_base` в теле запроса.

## Remaining

- Настоящий поток токенов с сервера (SSE или WebSocket — контракт KB App API).
- Режимы «с БЗ» / «пустой чат» на стороне сервера (клиент уже шлёт флаг).
