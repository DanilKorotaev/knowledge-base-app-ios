# Chat: text send + history

**Status:** Client MVP готов (stub + HTTP заготовка); ответы ассистента по сети — когда API готов.

## Done

- `ChatAPIClientProtocol`, stub с демо-сессией, `URLSession` для messages.
- Экран чата, переключатель use KB, пузырьки user/assistant.

## Remaining

- Streaming assistant tokens (SSE/WebSocket — TBD).
- Режимы «с БЗ» / «пустой чат» на стороне сервера (клиент уже шлёт флаг).
