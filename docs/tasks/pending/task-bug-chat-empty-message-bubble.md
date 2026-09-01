# Bug: пустой bubble в чате (место есть, контента не видно)

**Статус:** Запланировано (частично mitigated rollback optimistic)  
**Приоритет:** Высокий  
**Категория:** Баг, UI чата

## Симптомы

- Сообщение (часто после **неудачной** отправки голоса/compose) занимает высоту в ленте, но **текст/вложения не видны**.
- Пользователь описывал это и для «последнего ответа ассистента».

## Вероятные причины

### 1. Optimistic user message после failed send (mitigated)

`buildOptimisticMessage` для compose с голосом + фото:

- `bubbleTextContent` → `nil` (логика `isVoiceOnly` / `contentDuplicatesVoiceTranscription`).
- Вложения с `downloadURL: file://…` — **локальные пути**; `VoiceMessageBubble` / `AttachmentImageGrid` могут не отрисовать их.
- Итог: padding bubble без видимого контента.

**Mitigation:** удаление `kb-optimistic-*` при ошибке send (`task-bug-composer-send-voice-attachments-failure`).

### 2. Assistant message / streaming

- `StreamingAssistantBubbleView` с пустым `text` и завершённым stream.
- Ответ ассистента только из `structured_ui` без markdown body.
- Markdown/HTML рендер с «невидимым» контентом (цвет, пустые блоки).

## Задачи

- [ ] В `RichMessageBubbleView`: fallback «Сообщение без отображаемого текста» / иконка, если нет ни текста, ни загруженных attachment.
- [ ] Optimistic compose: показывать **текст транскрипции** явно, не полагаться только на voice attachment player для local file.
- [ ] Проверить `KBMessage.bubbleTextContent` для optimistic-сообщений с voice+text.
- [ ] Assistant: если `content` пустой после `reloadLatestWindow`, не оставлять пустой placeholder в ленте.
- [ ] Регрессионный UI-тест / snapshot для compose optimistic bubble.

## Связанные задачи

- `task-bug-composer-send-voice-attachments-failure.md`
- `task-ux-chat-rich-messages.md` (completed)
