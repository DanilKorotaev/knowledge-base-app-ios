# Bug: send «успешен» локально, на сервере пусто — теряется draft/голос

**Статус:** 🟡 P0 в коде (2026-09-12) — merge fix + draft clear после ack; полный SendOutboxStore ещё в P1  
**Приоритет:** 🔴 Высокий (потеря пользовательских данных)  
**Категория:** Баг, композер, optimistic UI, outbox  
**Инцидент:** 2026-09-11 — чат «Тренировки» (session 29)  
**Бэкенд (парная задача):** `knowledge-base-bot/docs/tasks/pending/task-api-compose-client-message-id-ack.md`

## План работ (iOS)

### P0 — стоп потери данных

- [x] Fix `mergeOlderLoadedMessages` (не снимать optimistic по любому historical user).
- [x] `clearSavedComposerDraft()` после ack / полного успеха; resumable без ack draft не чистит.
- [x] `finishHardSendFailure` с `preSendLastMessageId` + `serverAcceptedCurrentSend`.
- [x] Compose: `client_message_id` + SSE `user_message_acked`.
- [x] Unit tests: merge с историей; SSE ack decode.

### P1 — Outbox

- [ ] `SendOutboxStore` (App Group).
- [ ] Явные bubble states `sending` / `failed`.
- [ ] `client_message_id` на text/voice endpoints.

## Acceptance

- [x] Unit: длинный чат — optimistic не пропадает без нового user turn.
- [ ] Airplane / kill app E2E на TestFlight.
- [ ] Успешный compose → draft cleared после ack.
