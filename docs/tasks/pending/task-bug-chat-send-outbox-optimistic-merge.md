# Bug: send «успешен» локально, на сервере пусто — теряется draft/голос

**Статус:** 📋 Запланировано  
**Приоритет:** 🔴 Высокий (потеря пользовательских данных)  
**Категория:** Баг, композер, optimistic UI, outbox  
**Инцидент:** 2026-09-11 — чат «Тренировки» (session 29): 3× `POST /voice/transcribe` ок, `compose` на API не дошёл; в UI было waiting без Cursor-статуса; после — ни исходящего, ни ответа.  
**Бэкенд (парная задача):** `knowledge-base-bot/docs/tasks/pending/task-api-compose-client-message-id-ack.md`

## Симптомы

1. Голосовые расшифровались, chips в композере, пользователь нажал Send.
2. Появился optimistic bubble + «процессинг» (`.waiting`), **без** лейбла Cursor («подключаюсь» / tool activity).
3. После закрытия чата / обрыва: нет user-сообщения в истории, композер пуст, Retry нет.
4. На сервере: нет `messages` / attachments / access-log `compose` за этот момент.

## Корневые причины (разбор кода)

### A. Resumable interrupt = success → чистим draft

`handleResumableStreamInterruption` (`timedOut` / `networkConnectionLost` / `cancelled`) возвращает `true` → `send*` считает успех → `clearSavedComposerDraft()`, хотя сервер мог **не принять** multipart.

### B. Optimistic merge убивает bubble по «любому user в странице»

```swift
// ChatViewModel.mergeOlderLoadedMessages
let serverHasUser = fetched.contains { $0.role == .user }
// → в длинном чате всегда true → optimistic снимается на первом poll/reload
```

### C. Hard-fail после reload думает, что сервер уже ответил

`finishHardSendFailure` → `reloadLatestWindow()` → optimistic уже снят (B) → `messages.last` = **старый** assistant → `clearSavedComposerDraft()` + без Retry.

Итог: диск пуст, UI пуст, бэк пуст — восстановить нельзя.

## Целевое поведение

1. **Не считать send успешным** и **не чистить disk draft**, пока нет ack сервера (`message_id` / `client_message_id`).
2. Optimistic / outbox живут, пока ack не получен или пользователь явно не отменил.
3. При обрыве до ack: bubble `failed` / `sending` + **Retry** (из outbox snapshot), композер можно оставить пустым.
4. Cursor-статус — только после SSE; до ack UI честно говорит «отправляется» / «не доставлено», не «ждём ассистента в пустоту».

## План работ (iOS)

### P0 — стоп потери данных

- [ ] Fix `mergeOlderLoadedMessages`: снимать `kb-optimistic-*` только если сервер отдал **новый** user turn (id новее якоря / совпадение по `client_message_id`), не `fetched.contains { .user }`.
- [ ] `clearSavedComposerDraft()` **только** после подтверждённого persist user message (HTTP 2xx + id), не после resumable/`succeeded` от poll.
- [ ] Resumable SSE drop: оставлять outbox/draft до ack; poll только если ack уже был.
- [ ] `finishHardSendFailure`: не трактовать «last == старый assistant» как accept текущего send (сравнивать с pre-send last message id).
- [ ] Unit tests: merge с историей user; timeout до ack сохраняет draft store; hard fail показывает Retry.

### P1 — Outbox

- [ ] `SendOutboxStore` (App Group): `client_message_id`, sessionId, snapshot draft (текст + пути файлов), status `queued|sending|acked|failed`, timestamps.
- [ ] При Send: писать outbox **до** сети; UI читает outbox, не только in-memory optimistic.
- [ ] После ack: status `acked`, затем удаление snapshot (TTL опционально 24–72 ч для «недавние неудачные»).
- [ ] Retry из outbox; лимит размера (N сообщений / МБ на сессию).
- [ ] UX: явные состояния bubble `sending` / `failed` (не вечный orphan processing).

### P2 — контракт с API

- [ ] Слать `client_message_id` в `compose` / `messages` / `voice` (см. backend task).
- [ ] Идемпотентный retry тем же id после обрыва.

## Не делать

- Не логировать полный текст голосовых на сервер «на всякий случай».
- Не раздувать access-логи контентом; для отладки достаточно id + status.

## Файлы (ориентир)

- `KnowledgeBaseApp/ViewModels/ChatViewModel.swift`
- `KnowledgeBaseApp/Services/ComposerDraftStore.swift`
- `KnowledgeBaseApp/Services/InFlightReplyStore.swift` (`StreamInterruptionClassifier`)
- новый `SendOutboxStore` (+ tests)
- `KnowledgeBaseAppTests/…`

## Acceptance

- [ ] Airplane / kill app сразу после Send без ответа сервера → после reopen текст+голос в outbox/Retry, не потеряны.
- [ ] Успешный compose → outbox acked, draft disk cleared, optimistic заменён серверным id.
- [ ] Длинный чат с историей: optimistic не исчезает на poll, пока нет нового user message.
- [ ] Unit tests зелёные; ручной E2E на TestFlight.
