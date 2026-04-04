# Voice input — MVP (local recording + stub pipeline)

**Completed:** 2026-04-04

## Delivered

- `VoiceRecordingService` + `VoiceRecordingServiceProtocol` (AVAudioRecorder, AAC, metering).
- `RecordingGestureLogic` (pure thresholds) + unit tests.
- `VoiceRecordingViewModel` — hold / swipe left cancel / swipe up lock; haptics; post-record sheet with editable “transcription” draft.
- Отправка после записи идёт через `ChatAPIClientProtocol.sendVoiceRecording` (раньше был отдельный `VoiceUploadClient`; удалён).
- UI: `MicRecordControl`, `PostRecordingReviewSheet`, integrated in `MainView`.

## Follow-up

- Серверный `POST /api/query/voice` + pre-fill `transcriptionDraft` из ответа при необходимости.
- Polish animations (lock icon proximity), accessibility, longer recordings on device.
