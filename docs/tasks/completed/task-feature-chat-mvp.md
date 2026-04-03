# Chat — text + history (stub / HTTP)

**Completed:** 2026-04-04

## Delivered

- `KBMessage`, `MessageRole`; `ChatAPIClientProtocol` + `StubChatAPIClient` + `InMemoryKBStore` (demo session без сервера).
- `URLSessionKnowledgeBaseAPIClient` + `ChatAPIClientProtocol`: `GET/POST …/api/sessions/{id}/messages` (контракт на будущее).
- `ChatViewModel`, `ChatView` (`MessageBubbleView`), навигация из списка сессий.
- Toggle «Use knowledge base» (уходит в stub / в теле POST).
- Тесты: `ChatAPIClientTests`, `KBMessageTests`; обновлены stub session tests.

## Follow-up

- Стриминг токенов ответа ассистента.
- Связка с реальным KB App API после бэкенда.
