# Apple Watch: companion app + complication (голосовой ввод)

**Статус:** In progress (2026-06-18) — relay + offline queue готовы; **осталась complication (этап 3)**
**Приоритет:** 🟡 Средний (после E2E iPhone ↔ KB App API)  
**Категория:** Product / watchOS  
**Связанные документы:**

- [Концепция Apple Watch](../../../../Документация/iOS-приложение%20базы%20знаний/Концепция%20Apple%20Watch.md)
- [План реализации iOS-приложения](../../../../Документация/iOS-приложение%20базы%20знаний/План%20реализации%20iOS-приложения%20базы%20знаний.md) § 5.3
- [task-feature-default-voice-session.md](../completed/task-feature-default-voice-session.md) — дефолтная сессия для маршрутизации с Watch
- [task-feature-voice-input.md](../completed/task-feature-voice-input.md) — голос на iPhone
- [task-feature-widgets-app-intents.md](../completed/task-feature-widgets-app-intents.md) — аналог для iPhone (deep link `knowledgebase://record`)

## Контекст

На iPhone уже есть виджеты и App Intent с микрофоном (`StartVoiceRecordingIntent`, `knowledgebase://record`). Отдельное **watchOS-приложение** ещё не заведено в Xcode-проекте — есть только концепт-документ с чеклистом этапов.

Целевой UX: **complication на циферблате с иконкой микрофона** → тап → приложение на часах открывается **сразу в режиме записи** → голос уходит на iPhone → iPhone шлёт на KB App API в **дефолтную сессию** (см. отдельную задачу).

## Цели

1. Companion watchOS target в `knowledge-base-app-ios`.
2. Запись голоса на Watch, relay на iPhone через **WatchConnectivity** (`transferFile` / `sendMessage`).
3. Complication (WidgetKit, watchOS 10+): тап → deep link → мгновенный старт записи.
4. Оффлайн-очередь записей, если iPhone недоступен (сохранить локально → отправить при `sessionReachabilityDidChange`).
5. Краткий ответ на Watch (первые N символов + опционально TTS).

## Декомпозиция

### Этап 1 — Target и связь

- [x] Добавить watchOS target + shared scheme в XcodeGen/`project.yml`.
- [x] Настроить `WCSession` (activate в iOS и watchOS, делегаты).
- [x] Главный экран Watch: название **текущей дефолтной сессии** (из `applicationContext` с iPhone).

### Этап 2 — Запись и relay

- [x] `AVAudioRecorder` на Watch, UI записи (таймер, meter, отмена).
- [x] iPhone: обработчик входящего аудио → transcribe + `streamVoiceMessage` в дефолтную сессию.
- [x] Ответ сервера → краткий текст обратно на Watch (`updateApplicationContext`).

### Этап 2.5 — Оффлайн

- [x] Локальное сохранение при недоступности iPhone (`WatchPendingRecordingStore`).
- [x] Автоотправка очереди при `sessionReachabilityDidChange`.
- [x] Индикатор pending count на главном экране.

### Этап 3 — Complication

- [ ] `accessoryCircular` с `mic.fill`, `widgetURL` → `knowledgebase://record` (отдельный widget extension — follow-up).
- [ ] `onOpenURL` в Watch App → `startRecordingImmediately()`.
- [ ] Опционально: `accessoryInline` — имя дефолтной сессии; corner — счётчик pending.

### Этап 4 — Polish

- [x] `AVSpeechSynthesizer` для озвучивания ответа (кнопка Speak).
- [x] Haptic при успехе/ошибке.
- [ ] Список сессий на Watch (read-only sync) — **не MVP**, если есть дефолтная сессия на iPhone.

## Зависимости

| Зависимость | Зачем |
|-------------|--------|
| E2E голос iPhone ↔ API | Watch relay использует тот же пайплайн |
| [task-feature-default-voice-session.md](../completed/task-feature-default-voice-session.md) | Куда маршрутизировать запросы с Watch |
| TestFlight / provisioning | Отдельный bundle id для Watch extension |

## Acceptance

- [ ] Complication на симуляторе/устройстве: тап → запись стартует без лишних экранов.
- [ ] Аудио с Watch попадает в правильную сессию на сервере (через iPhone relay).
- [ ] При отсутствии iPhone запись сохраняется и доотправляется позже.
- [ ] Документация: `docs/DEVELOPMENT.md` + ссылка из README.

## Связанные файлы (ожидаемые)

- `KnowledgeBaseWatchApp/` (новый target)
- `Shared/WatchConnectivity/` — протокол relay
- `KnowledgeBaseApp/Services/WatchRelayService.swift` — приём аудио на iPhone
- `KnowledgeBaseWidgetExtension/` — переиспользование deep link scheme
