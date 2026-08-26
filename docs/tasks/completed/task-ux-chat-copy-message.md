# UX: копирование сообщения целиком (не только одного markdown-блока)

**Статус:** Реализовано (клиент) — 2026-08-26  
**Приоритет:** Средний  
**Категория:** UX чата, rich messages

## Решение

- Long-press на bubble → **Copy all** / **Open to copy**
- Copy all кладёт plain `message.content` (markdown/plain source) или transcription для voice-only
- Sheet: `UITextView` (plain text) — выделение произвольного диапазона; Copy всегда пишет `UIPasteboard.general.string` (не RTFD)
- EN/RU в `Localizable.xcstrings`

## Acceptance

- [x] Long-press assistant → Copy all
- [x] Sheet Open to copy с выделением фрагмента (UITextView)
- [x] Copy из sheet → plain text (не RTFD)
- [x] User bubble тоже
- [x] Unit: markdown source + voice transcription fallback
- [ ] Ручная приёмка TestFlight

## Файлы

- `MessageCopyContent.swift`
- `MessageCopySheet.swift`
- `RichMessageBubbleView.swift`
- `Localizable.xcstrings`
