# Chat: SSE streaming + production integration

**Completed:** 2026-06-10  
**Prod verified:** text SSE, compose multipart, streaming UX (Session 109).

**Follow-up MVP:** [task-feature-chat-mvp.md](task-feature-chat-mvp.md) (HTTP shapes + stub).

## Delivered

### Client

- `ChatAPIClientProtocol`, `URLSessionKnowledgeBaseAPIClient` for messages.
- `streamTextMessage` — `Accept: text/event-stream`, SSE `data:` + `ChatSSEEvent`, JSON fallback.
- `streamComposedMessage` — multipart compose + SSE.
- Optimistic user bubble before stream; thread reload after stream completes.
- `SSEventParser` / `StreamBuffer` — `\r\n` → `\n` normalization.

### UX (see also completed tasks)

- [task-ux-chat-streaming-feedback.md](task-ux-chat-streaming-feedback.md) — spinner, typing dots, typewriter reveal.
- [task-ux-chat-composer-telegram.md](task-ux-chat-composer-telegram.md) — composer + compose API.
- [task-ux-chat-rich-messages.md](task-ux-chat-rich-messages.md) — rich bubbles.

### Server (backend repo)

- SSE `processing` + split deltas; nginx `proxy_buffering off` on prod.

## Acceptance

- [x] Client sends `use_knowledge_base` flag.
- [x] Assistant reply streams in UI on prod HTTPS.
- [x] Compose (text + attachments + voice) → single user message + streamed assistant reply.

## Out of scope (ongoing)

- Automated E2E for SSE/voice/compose — [task-backend-kb-app-api-sync.md](../pending/task-backend-kb-app-api-sync.md).
- Server-side «с БЗ / пустой чат» policy tuning (client already sends flag).
