# Voice input (hold + lock)

**Status:** In progress — **client wired to chat API**; Whisper + server pipeline — задача в репо бота.

## Done (iOS)

- AVFoundation capture (`VoiceRecordingService`).
- Hold-to-record, swipe left cancel, swipe up lock (`MicRecordControl` + `RecordingGestureLogic` tests).
- Haptics; timer + level-based waveform strip.
- Post-record sheet; send через `ChatAPIClientProtocol.sendVoiceRecording` (stub или `POST /api/query/voice`).
- `VoiceRoutingContext`: сессия и toggle «с БЗ» с открытого чата; иначе fallback на первую сессию в списке.
- После успешной отправки — `Notification.Name.kbSessionThreadDidChange`: открытый чат и список сессий подтягивают данные.

## Remaining

- Сервер: `POST /api/query/voice` — см. `knowledge-base-bot/docs/tasks/pending/task-api-kb-app-voice-query-ios.md`.
- Опционально: pre-fill `transcriptionDraft` из поля `transcription` в ответе API.
- Optional UI tests / gesture polish on device (mic permission).

## Acceptance

- [x] Unit tests for gesture thresholds.
- [ ] Integration test or manual QA checklist on device (mic permission).
