# UX: ошибка ответа — Retry на bubble, без возврата текста в композер

**Статус:** Реализовано (клиент) — 2026-08-26  
**Приоритет:** Высокий  
**Категория:** UX чата, ошибки, composer draft

## Проблема

После отправки бывают сценарии:

1. **Сервер записал в чат сообщение-ошибку** («произошла ошибка, обратитесь к администратору») — пайплайн формально «завершён», ошибка уже в ленте.
2. **Таймаут / обрыв клиента**, после чего ответ всё же появляется (или ошибка уже в истории).

Раньше клиент часто:

- считал send failed;
- **восстанавливал черновик** в поле ввода;
- пользователю приходилось вручную чистить композер.

## Решение (iOS)

1. Hard send failure → composer остаётся пустым; optimistic bubble сохраняется; `pendingSendRetry` + кнопка «Повторить» под bubble.
2. Если после fail reload уже видит assistant (в т.ч. pipeline error) → draft очищен, Retry на error-assistant («спросить снова» тем же текстом).
3. Resumable SSE drop → без restore draft (см. resume-streaming).
4. Alert не показывается, пока есть `pendingSendRetry` (ошибка рядом с Retry).

## Acceptance

- [x] Серверная ошибка в ленте → input пустой, draft на диске очищен; Retry на assistant.
- [x] Hard fail до ответа → optimistic + Retry, composer пустой (не restore draft).
- [x] Unit: classifier pipeline error; fail без restore; fail + assistant error → Retry text.
- [ ] Ручная приёмка TestFlight: offline/fail send → Retry; pipeline error → Retry.

## Затронутые файлы

- `KnowledgeBaseApp/Models/FailedSendRetry.swift`
- `KnowledgeBaseApp/ViewModels/ChatViewModel.swift`
- `KnowledgeBaseApp/Views/Chat/ChatView.swift`
- `KnowledgeBaseApp/Views/Chat/MessageSendRetryBar.swift`
- `SharedLocalization/Localizable.xcstrings`
- tests

## Связанные задачи

- `task-ux-chat-resume-streaming-after-background.md` (completed)
- `task-ux-chat-copy-message.md` — следующая
