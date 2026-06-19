# UX: отображение активности Cursor (SSE `activity`) во время долгого ответа

**Status:** Partial — contract + `ChatSSEEvent` fields (UI in [task-ux-cursor-activity-streaming.md](task-ux-cursor-activity-streaming.md))
**Priority:** Medium (depends on backend stream-json)  
**Category:** Chat UX / streaming  

**Backend spec:** [task-cursor-cli-stream-json-progress.md](../../../knowledge-base-bot/docs/tasks/pending/task-cursor-cli-stream-json-progress.md) (фаза 2+)  
**Related:** [task-ux-chat-streaming-feedback.md](../completed/task-ux-chat-streaming-feedback.md), `KB_APP_API_CONTRACT.md`

## Problem

While the assistant works (reads files, runs tests, writes code), the user sees only **«Обработка…»** with a spinner until the first text `delta` arrives. On heavy tasks this can be **many minutes** with no feedback — and the backend may have already timed out before any text appears.

Backend plan: emit SSE events when `cursor-agent` runs tools:

```json
{"activity": "tool", "label": "Запускаю тесты…"}
```

## Goal

Show **what the agent is doing** under the pending bubble (or inline status), without changing the final message rendering.

## Scope

### Phase A — Contract + model (after backend фаза 2)

- [x] Extend `ChatSSEEvent` (`Networking/ChatSSEEvent.swift`): `activity`, `label`
- [x] Update `docs/KB_APP_API_CONTRACT.md`
- [ ] `KnowledgeBaseAPIClient.handleSSEChatPayload`: surface activity to ViewModel

### Phase B — ViewModel + UI

- [ ] `ChatViewModel` / streaming state: `cursorActivityLabel: String?` updated on `activity` events; cleared on first `delta` or `done`.
- [ ] `AssistantPendingBubbleView`: optional subtitle under «Обработка…» (`activityLabel`).
- [ ] Accessibility: announce activity changes sparingly (avoid VoiceOver spam).

### Phase C — Tests

- [ ] Unit: decode SSE payload with `activity` + `label`.
- [ ] Unit: `ChatViewModel` sets/clears activity label through mock stream.
- [ ] Optional UI test: pending bubble shows subtitle when activity present.

## Out of scope

- Parsing `cursor-agent` NDJSON on device (server-only).
- `--stream-partial-output` character deltas (backend фаза 3; existing typewriter already handles `delta`).
- Cancel button for long requests (Telegram has it; app — separate task if needed).

## Acceptance

- [ ] During a long backend job, user sees updating status lines (e.g. «Читаю …», «Выполняю …») before answer text streams.
- [ ] When `delta` arrives, activity line hides; streaming bubble behaves as today.
- [ ] Client works if server sends only `processing` / `delta` / `done` (no `activity`) — no regression.

## Depends on

- Backend: [task-cursor-cli-stream-json-progress.md](../../../knowledge-base-bot/docs/tasks/pending/task-cursor-cli-stream-json-progress.md) **фаза 2** (SSE `activity` events deployed).
