# Chat UX: processing indicator, streaming bubble, typing animation

**Status:** Pending — backend SSE exists; iOS shows stream only after first non-empty delta.

**Master spec (Obsidian):** `Документация/Задачи/task-kb-app-chat-streaming-ux.md`

## Problem

After send, user sees optimistic user bubble only. No feedback while backend syncs + Cursor starts. Streaming bubble appears only when `streamingAssistantText != ""`.

## Current code

- `ChatViewModel.send()` — `streamTextMessage`, `streamingAssistantText`, `reloadLatestWindow()` on done.
- `ChatView` — assistant bubble gated on non-empty streaming text (lines ~58–70).
- `VoiceRecordingViewModel.confirmPostRecordUpload` — discards stream chunks.

## Implementation checklist

### State

- [ ] `AssistantReplyPhase`: `idle | waiting | streaming(String) | finalizing`
- [ ] Set `waiting` immediately after optimistic user append, before first SSE byte
- [ ] Do not clear streaming UI until server messages replace it

### Views

- [ ] `TypingIndicatorView` — three bouncing dots
- [ ] `AssistantPendingBubbleView` — spinner + «Processing…» / localized RU string
- [ ] Wire in `ChatView` for `waiting` and `streaming`

### Voice

- [ ] Share streaming state with open chat (notification or shared view model) when sending from mic flow

### Optional backend (phase 2)

- [ ] Parse SSE `{"status":"processing"}` — extend `ChatSSEEvent` + contract

## Tests

- [ ] `ChatViewModel` phase transitions
- [ ] No regression in `KnowledgeBaseAPIClientTests` SSE parsing

## Acceptance

- [ ] Spinner/placeholder visible before first delta
- [ ] Text grows with typing dots during stream
- [ ] Final message from DB replaces placeholder without flash
- [ ] Error path shows alert and reloads thread
