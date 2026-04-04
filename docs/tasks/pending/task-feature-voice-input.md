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
- Optional UI tests / gesture polish on device (mic permission).

## Done (client follow-up)

- `VoiceRecordingSendResult` + декодирование `transcription` в `URLSessionKnowledgeBaseAPIClient`; stub отдаёт stub-ASR при пустой подсказке.
- Pre-fill `transcriptionDraft` после успешной отправки, если поле было пустым (короткая задержка перед закрытием листа); индикатор отправки на листе.

## Acceptance

- [x] Unit tests for gesture thresholds.
- [ ] Integration test or manual QA checklist on device (mic permission).
