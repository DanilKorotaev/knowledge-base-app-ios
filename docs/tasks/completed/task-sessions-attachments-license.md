# New session + attachments + MIT license

**Completed:** 2026-04-04

## Sessions

- `KnowledgeBaseAPIClientProtocol.createSession(title:)`
- Stub via `InMemoryKBStore.createSession`; HTTP `POST /api/sessions` with JSON `{"title":...}`
- UI: toolbar **+**, `NewSessionSheet`

## Attachments (MVP)

- `ChatAPIClientProtocol.sendAttachment(...)` — stub + multipart `POST …/api/sessions/{id}/attachments`
- `ChatView`: PhotosPicker (images), file importer, `URL.kbPreferredMIMEType`
- `Info.plist`: photo library + camera usage strings

## License

- Root `LICENSE` (MIT), README updated
