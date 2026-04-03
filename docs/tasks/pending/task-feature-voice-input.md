# Voice input (hold + lock)

**Status:** In progress — **client MVP done**; real upload + Whisper pending KB App API.

## Done (iOS)

- AVFoundation capture (`VoiceRecordingService`).
- Hold-to-record, swipe left cancel, swipe up lock (`MicRecordControl` + `RecordingGestureLogic` tests).
- Haptics; timer + level-based waveform strip.
- Post-record sheet with editable transcription draft; `StubVoiceUploadClient` until API exists.

## Remaining

- KB App API: audio upload + Whisper → fill transcription before send.
- Optional UI tests / gesture polish.

## Acceptance

- [x] Unit tests for gesture thresholds.
- [ ] Integration test or manual QA checklist on device (mic permission).
