# Чат: вложения, голос, Markdown/HTML в пузырях

**Статус:** ✅ Выполнено  
**Приоритет:** 🟠 Высокий  
**Категория:** UX / Chat  
**Дата завершения:** 2026-06-01  
**Backend:** [task-api-messages-rich-content.md](../../../knowledge-base-bot/docs/tasks/completed/task-api-messages-rich-content.md)  
**Связанные:** [task-feature-chat.md](../completed/task-feature-chat.md), [task-sessions-attachments-license.md](../completed/task-sessions-attachments-license.md)

## Реализовано

- Модели `KBAttachment`, расширенный `KBMessage` (`content_format`, `attachments`, `transcription`).
- `RichMessageBubbleView` — image grid + fullscreen, `VoiceMessageBubble` (play/pause, collapse для voice-only).
- `MessageContentView` — Markdown (`AttributedString`) и HTML (whitelist через `NSAttributedString`).
- `KBAttachmentLoaderProtocol` + stub / `URLSessionKnowledgeBaseAPIClient` для auth download.
- Demo fixtures в `InMemoryKBStore`; unit-тесты в `KBMessageTests`.

## Файлы

- `KnowledgeBaseApp/Models/KBAttachment.swift`, `KBMessage.swift`
- `KnowledgeBaseApp/Views/Chat/RichMessageBubbleView.swift`, `AttachmentImageGrid.swift`, `VoiceMessageBubble.swift`, `MessageContentView.swift`
- `KnowledgeBaseApp/Services/KBAttachmentLoader.swift`

## Acceptance

- [x] В чате видны отправленные фото из истории сессии.
- [x] Голосовое сообщение можно прослушать; транскрипция видна; voice-only сворачивается.
- [x] Ответ ассистента с `**bold**` и списками отображается читаемо; HTML из API не ломает layout.
