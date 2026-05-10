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
- QA на устройстве: микрофон, отправка голоса, появление транскрипта/сообщений в треде (E2E по HTTP в `docs/testing/E2E.md` голос не покрывает).

## Done (client follow-up)

- `VoiceRecordingSendResult` + декодирование `transcription` в `URLSessionKnowledgeBaseAPIClient`; stub отдаёт stub-ASR при пустой подсказке.
- Pre-fill `transcriptionDraft` после успешной отправки, если поле было пустым (короткая задержка перед закрытием листа); индикатор отправки на листе.

## Acceptance

- [x] Unit tests for gesture thresholds.
- [ ] Ручной чеклист на устройстве: разрешение микрофона → удержание записи → отпускание → отправка → сообщение/транскрипт в чате; при необходимости отмена свайпом влево и lock свайпом вверх.
- [ ] (Опционально) UI-тесты жестов на симуляторе без реального микрофона.

## Manual QA (кратко)

1. Настроить API base URL и токен в приложении (как для обычного чата).
2. Открыть сессию, нажать микрофон, записать короткую фразу, отпустить.
3. Убедиться, что запрос уходит без ошибки и в треде появляется ответ сервера (или черновик транскрипта по UX приложения).

См. также `docs/testing/E2E.md` для проверки REST без UI.
