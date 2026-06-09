# Дефолтная сессия для голосовых запросов (iPhone + Watch)

**Статус:** Delivered (2026-06-09) — client-only MVP; Watch context sync stub ready  
**Приоритет:** 🟠 Высокий  
**Категория:** Product / UX  

**Связанные задачи:**

- [task-feature-watch-app-voice.md](../pending/task-feature-watch-app-voice.md)
- [task-feature-voice-input.md](../pending/task-feature-voice-input.md)

## Проблема

Голос с главного экрана / widget попадал в **первую** сессию списка. Нужен явный «рабочий контекст» с опциональным TTL.

## Delivered

- [x] `DefaultVoiceSessionPreference` + `DefaultVoiceSessionStore` (UserDefaults JSON)
- [x] `VoiceSessionTargetResolver` — open chat > valid default > first session
- [x] `VoiceRoutingContext` — set/clear default, TTL expiry, restore `previousSessionId`
- [x] UI: swipe/context menu **Voice default**, TTL sheet, mic bar indicator, Settings clear
- [x] Main-screen recording with voice default → opens target chat + composer enqueue (no review sheet)
- [x] `PostRecordingReviewSheet` when no voice default (widget / future Watch)
- [x] `WatchVoiceSessionContextSync` — `WCSession.updateApplicationContext` when paired
- [x] Unit tests: `DefaultVoiceSessionTests.swift`
- [x] `docs/DEVELOPMENT.md`

## Acceptance

- [x] С главного экрана голос уходит в выбранную дефолтную сессию
- [x] После TTL дефолт сбрасывается (или восстанавливается previous)
- [x] Watch получает context с iPhone (когда Watch app установлен)

## Follow-up

- [ ] Server-side prefs (`task-api-session-crud-extensions.md`) для синка между устройствами
- [ ] Watch relay consume context in Watch target (blocked on `task-feature-watch-app-voice.md`)
