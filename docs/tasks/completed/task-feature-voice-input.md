# Voice input: production pipeline (Whisper + chat)

**Completed:** 2026-06-10  
**Prod E2E:** Session 109 — voice + compose; default session → chat composer handoff.

**Follow-up MVP:** [task-feature-voice-input-mvp.md](task-feature-voice-input-mvp.md) (local recording UI).

## Delivered

### Capture & gestures

- AVFoundation capture (`VoiceRecordingService`).
- Hold-to-record, swipe left cancel, swipe up lock (`MicRecordControl` + `RecordingGestureLogic` tests).
- Haptics; timer + level-based waveform strip.

### API integration

- `transcribeVoiceRecording` → `POST /api/query/voice` (ASR only).
- `streamVoiceMessage` / `sendVoiceRecording` — voice + text in thread.
- Compose path: voice clips in `ChatComposerDraft` → `POST …/messages/compose`.
- `VoiceRecordingSendResult` + decoding `transcription` in `URLSessionKnowledgeBaseAPIClient`.

### Routing

- `VoiceRoutingContext` + `VoiceSessionTargetResolver` — open chat → valid default → first session.
- Default voice session: main-screen recording opens target chat + composer enqueue (no review sheet).
- `PostRecordingReviewSheet` when no voice default (widget / future Watch).
- `Notification.Name.kbSessionThreadDidChange` after send.

## Acceptance

- [x] Unit tests for gesture thresholds.
- [x] Prod: mic → transcribe → message in thread (composer + legacy review paths).
- [ ] (Optional) UI-тесты жестов на симуляторе без реального микрофона.

## Related

- [task-feature-default-voice-session.md](task-feature-default-voice-session.md)
- [task-ux-chat-composer-telegram.md](task-ux-chat-composer-telegram.md)
- Backend: `knowledge-base-bot/docs/tasks/completed/task-api-kb-app-voice-query-ios.md`
