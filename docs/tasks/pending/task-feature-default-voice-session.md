# Дефолтная сессия для голосовых запросов (iPhone + Watch)

**Статус:** 📋 Запланировано  
**Приоритет:** 🟠 Высокий  
**Категория:** Product / UX  
**Связанные задачи:**

- [task-feature-watch-app-voice.md](task-feature-watch-app-voice.md)
- [task-feature-voice-input.md](task-feature-voice-input.md)
- Backend: [task-api-session-crud-extensions.md](../../../knowledge-base-bot/docs/tasks/pending/task-api-session-crud-extensions.md) (опционально server-side prefs)

## Проблема

Сейчас `VoiceRoutingContext` маршрутизирует голос так:

- если открыт чат — в **активную** сессию этого экрана;
- иначе — в **первую** сессию списка (`PostRecordingReviewSheet`, mic bar на `MainView`).

Нет явного выбора «рабочего контекста» для быстрых голосовых заметок с часов или с главного экрана без открытого чата.

## Сценарии

| Сценарий | Дефолтная сессия | TTL |
|----------|------------------|-----|
| Повседневные дела (календарь, напоминания, список покупок) | «Дела / inbox» | Без лимита или «до сброса» |
| Чтение книги на английском | «Wonder — словарь» | 1 час → сброс на предыдущую / none |

## Цели

1. В приложении выбрать **дефолтную сессию** для голосовых запросов (mic bar, widget deep link, Watch relay).
2. Опционально задать **длительность** (30 мин / 1 ч / 2 ч / до конца дня / бессрочно).
3. По истечении TTL — автоматический сброс дефолта (уведомление / badge в UI).
4. Синхронизация выбора на Watch через `WCSession.updateApplicationContext`.

## UI (предложение)

- Экран списка сессий: swipe action или context menu **«Сделать дефолтной для голоса»**.
- Sheet выбора TTL при назначении дефолта.
- Индикатор на `MainView` / mic bar: «🎙 → [название сессии] · 42 мин».
- Settings или отдельная секция: сброс дефолта вручную.

## Техническая реализация (iOS)

- Модель `DefaultVoiceSessionPreference`:
  - `sessionId: String`
  - `expiresAt: Date?` (nil = бессрочно)
  - `previousSessionId: String?` (для restore после TTL — опционально)
- Хранение: `UserDefaults` / `@AppStorage` (Keychain не нужен — не секрет).
- `VoiceRoutingContext` расширить:
  - `defaultSessionId`, `defaultSessionExpiresAt`
  - `resolvedVoiceTargetSessionId`: open chat > valid default > first session
- Timer / `scenePhase` check для expiry.
- Watch: пушить `{ default_session_id, default_session_title, expires_at }` в applicationContext.

## Backend

**MVP — client-only** (UserDefaults на iPhone). Server-side prefs — опционально в `task-api-session-crud-extensions.md`, если нужна синхронизация между устройствами.

## Чеклист

- [ ] Модель + persistence дефолтной сессии и TTL.
- [ ] UI выбора сессии и TTL; индикатор активного дефолта.
- [ ] Интеграция в `VoiceRoutingContext`, `PostRecordingReviewSheet`, widget/intent deep link.
- [ ] Автосброс по TTL + ручной сброс.
- [ ] Unit-тесты: resolution order, expiry logic.
- [ ] Документация в `docs/DEVELOPMENT.md`.

## Acceptance

- [ ] С главного экрана (без открытого чата) голос уходит в выбранную дефолтную сессию.
- [ ] После истечения TTL дефолт сбрасывается; следующий голосовой запрос не попадает в просроченную сессию.
- [ ] Watch получает актуальное имя дефолтной сессии через iPhone (когда Watch target готов).
