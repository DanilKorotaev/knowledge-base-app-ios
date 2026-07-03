# Voice transcription failure: inline retry without losing recording

**Completed:** 2026-07-03  
**Priority:** High  
**Category:** UX / Reliability  
**Related:**

- [task-feature-voice-input.md](task-feature-voice-input.md)
- [task-ux-chat-composer-telegram.md](task-ux-chat-composer-telegram.md)
- [task-feature-watch-app-voice.md](../pending/task-feature-watch-app-voice.md)

## Problem

Если на этапе транскрибации/отправки голоса происходит ошибка, пользователь может потерять ценный записанный контент. Текущий UX с alert-нотификацией недостаточен: нужен явный экранный retry-path и гарантированное сохранение аудио до успешной отправки или ручного удаления.

## Delivered

- [x] `PendingVoiceStore` — копия записи в Caches до успеха/discard.
- [x] Composer: `PendingVoiceCapture` с состояниями `transcribing` / `failed`, inline `Повторить` / `Удалить`.
- [x] Post-record sheet: фазы `loading` / `ready` / `failed`, кнопка «Повторить».
- [x] Ошибки транскрибации не удаляют файл; retry на том же `audioURL`.
- [x] Отправка: draft и voice-файлы сохраняются при ошибке send; удаление только после успеха.
- [x] `VoicePipelineErrorMessage` — понятные тексты (сеть, таймаут, VPN).
- [x] Тесты: `PendingVoiceStoreTests`, `ChatViewModelVoiceRetryTests`.
- [x] Бэкенд: `transcription_user_message()` для timeout/connection в `/voice/transcribe`.

## Acceptance

- [x] При ошибке пользователь видит inline кнопку `Retry` в UI записи/композера.
- [x] Нажатие `Retry` повторяет pipeline на том же аудиофайле.
- [x] Голос не теряется после ошибки (не зависит от alert).
- [x] Пользователь может несколько раз retry без повторной записи.
- [x] Есть тесты на сценарии ошибок транскрибации с проверкой, что файл не удаляется преждевременно.
