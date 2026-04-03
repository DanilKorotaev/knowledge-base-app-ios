# Voice input — MVP (local recording + stub pipeline)

**Completed:** 2026-04-04

## Delivered

- `VoiceRecordingService` + `VoiceRecordingServiceProtocol` (AVAudioRecorder, AAC, metering).
- `RecordingGestureLogic` (pure thresholds) + unit tests.
- `VoiceRecordingViewModel` — hold / swipe left cancel / swipe up lock; haptics; post-record sheet with editable “transcription” draft.
- `StubVoiceUploadClient` — placeholder until KB App API accepts multipart audio + Whisper.
- UI: `MicRecordControl`, `PostRecordingReviewSheet`, integrated in `MainView`.

## Follow-up

- Wire `VoiceUploadClient` to real endpoint + pre-fill `transcriptionDraft` from Whisper response.
- Polish animations (lock icon proximity), accessibility, longer recordings on device.
