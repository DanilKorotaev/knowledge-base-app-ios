# UX: копирование сообщения целиком (не только одного markdown-блока)

**Статус:** Запланировано  
**Приоритет:** Средний  
**Категория:** UX чата, rich messages

## Проблема

Ответ ассистента рендерится **блоками** (markdown segments / tables / code). Long-press / `textSelection` даёт меню «Скопировать» только для **одного** фрагмента. Скопировать весь ответ целиком нельзя.

Нужно:

1. копировать **всё сообщение** (plain / markdown source);
2. желательно открывать **отдельный экран/sheet** с полным текстом bubble, где можно выделить фрагмент точнее (в т.ч. с сохранением markdown, где уместно).

## Цель

Удобное копирование содержимого bubble: целиком одной кнопкой + опциональный «режим выбора» в отдельном окне.

## Предлагаемый подход (анализ)

### MVP

- Context menu / long-press на bubble (не только на Text):
  - **Copy all** → `UIPasteboard` с `message.content` (сырой markdown/plain с сервера) или собранный plain из блоков.
- Для user bubbles — то же по `content`.

### v1.1

- Пункт **«Открыть для копирования»** → sheet:
  - `TextEditor` / selectable `Text` на полный `content`;
  - кнопки: Copy all, Copy as plain, (опционально) Copy as Markdown;
  - для таблиц/code — полный исходник из `content`, не только видимый layout.

### Ограничения

- Не ломать текущий `textSelection` внутри блоков (локальное выделение остаётся).
- Вложения (фото/voice) в copy all не включать; только текст / markdown source.
- HTML-format сообщения: копировать разумный plain или исходный `content` — зафиксировать в acceptance.

## Acceptance

- [ ] Long-press на assistant bubble → «Copy all» кладёт весь текст ответа в буфер.
- [ ] Sheet «Open to copy» показывает полный текст; можно выделить часть и скопировать системой.
- [ ] User bubble также поддерживает Copy all.
- [ ] Сообщение с несколькими markdown-блоками копируется целиком, не один абзац.
- [ ] Локализация EN/RU для пунктов меню.

## Затронутые файлы (ориентир)

- `RichMessageBubbleView.swift`
- `MessageContentView.swift` / markdown block views
- новый `MessageCopySheet.swift` (или подобный)

## Связанные задачи

- `task-ux-chat-rich-messages.md` (completed)
- `task-ux-chat-markdown-blocks.md` (completed)
