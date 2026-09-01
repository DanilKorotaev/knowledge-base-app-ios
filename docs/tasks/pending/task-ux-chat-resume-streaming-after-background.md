# UX: возобновление стриминга ответа после фона / ухода с чата

**Статус:** Реализовано (клиент) — 2026-08-25  
**Приоритет:** Высокий  
**Категория:** UX чата, стриминг, жизненный цикл приложения

## Проблема

Пользователь сворачивает приложение или уходит с экрана чата, пока ассистент ещё отвечает. При возврате видел «соединение потеряно», хотя ответ на сервере ещё мог дописываться.

Корневая причина: `resumeAwaitingReplyIfNeeded()` блокировался через `guard !isSending`, а вызывался из `catch` стрима, пока `isSending == true` — resume никогда не стартовал, показывалась ошибка сети.

## Решение (iOS)

1. `InFlightReplyStore` — персист маркера in-flight (sessionId, startedAt, partialText).
2. При старте стрима — `beginInFlightReply()`; на delta — update partial; на успех — clear.
3. `StreamInterruptionClassifier.isResumable` — URLError cancelled/timedOut/connectionLost/… и `CancellationError`.
4. На resumable drop: без `errorMessage`, phase waiting/streaming(partial), фоновый poll.
5. `ChatView`: snapshot на background/inactive; resume на `active` и `onAppear`.
6. `reloadLatestWindow` не сбрасывает waiting UI, пока маркер жив и last = user.

Backend не менялся (достаточно клиентского poll messages).

## Acceptance

- [x] Unit: network drop mid-stream → нет errorMessage, placeholder/waiting, partial сохранён
- [x] Unit: init восстанавливает streaming UI из маркера
- [x] Unit: store save/load/expire; classifier
- [ ] Ручная приёмка на TestFlight: свернуть во время ответа → вернуться без alert, виден waiting/streaming

## Затронутые файлы

- `KnowledgeBaseApp/Services/InFlightReplyStore.swift`
- `KnowledgeBaseApp/ViewModels/ChatViewModel.swift`
- `KnowledgeBaseApp/Views/Chat/ChatView.swift`
- `KnowledgeBaseAppTests/InFlightReplyStoreTests.swift`

## Связанные задачи

- `task-ux-chat-error-retry-instead-of-draft-restore.md` — следующая
- `task-ux-chat-streaming-feedback.md` (completed)
