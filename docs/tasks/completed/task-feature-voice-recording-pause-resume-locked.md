# Voice recording: pause/resume in LOCKED mode

**Status:** Completed  
**Priority:** High  
**Category:** Product / Voice UX  
**Related:**

- [task-feature-voice-input.md](../completed/task-feature-voice-input.md)
- [task-ux-chat-composer-telegram.md](../completed/task-ux-chat-composer-telegram.md)
- [task-feature-watch-app-voice.md](task-feature-watch-app-voice.md)

## Problem

В режиме записи `LOCKED` сейчас не хватает безопасной паузы/возобновления. Пользователь может записывать длинный голосовой запрос с перерывами, блокировать экран и продолжать позже, но итог должен быть одним сообщением без потери уже записанного.

## Goal

Добавить надежный цикл `pause → resume` в `LOCKED` режиме с сохранением одного итогового аудиофайла (логически непрерывного), поддержкой нескольких пауз подряд и восстановлением после `screen lock` / возврата в приложение.

## Scope (v1)

- [x] В UI `LOCKED` добавить явные действия `Pause` и `Resume`.
- [x] При паузе запись не теряется, состояние сессии записи сохраняется.
- [x] При `Resume` запись продолжается в тот же итоговый артефакт (один voice attachment для отправки).
- [x] Поддержать несколько циклов `Pause/Resume` до финального `Stop/Send`.
- [x] Корректно обрабатывать переходы app lifecycle (`active`/`inactive`/`background`) во время paused-состояния.
- [x] Обновить таймер/индикатор длительности: показывать накопленную длительность, а не только текущий активный сегмент.

## Technical notes

- Сегменты записи + `VoiceAudioMerger` (AVMutableComposition) в один `.m4a` при «Готово».
- `VoiceRecordingSessionLogic` — pure state machine для pause/resume и auto-pause на background.
- Auto-pause при уходе в background/inactive, пока запись активна в LOCKED.

## Acceptance

- [x] Пользователь может поставить запись на паузу в `LOCKED`, заблокировать экран, вернуться и продолжить запись.
- [x] После нескольких `Pause/Resume` отправляется одно голосовое сообщение.
- [x] В длительности итогового файла учитываются все записанные сегменты.
- [x] Нет потери данных при возврате из background, если запись была paused.
- [x] Есть unit/integration тесты на state machine `recording/paused/resumed/stopped`.

## Out of scope

- Редактирование записанного аудио (trim/удаление отдельных сегментов).
- Waveform editor и продвинутый монтаж.
