# Session KB mode: persistent setting at chat creation

**Status:** Completed  
**Priority:** Medium-High  
**Category:** UX / Sessions  
**Related:**

- [task-feature-chat.md](../completed/task-feature-chat.md)
- [task-feature-session-delete-rename.md](../completed/task-feature-session-delete-rename.md)

## Problem

Текущий toggle `Use Knowledge Base` в `Chat` navigation bar перегружает экран и выглядит как временная настройка “на лету”. Нужен более предсказуемый UX: режим должен задаваться при создании чата и быть перманентным для сессии.

## Goal

Перенести выбор режима `Use Knowledge Base` в flow создания новой сессии и убрать toggle из `Chat` navbar.

## Scope (v1)

- [x] Добавить поле/тоггл “Use Knowledge Base” в UI создания нового чата.
- [x] Сохранять выбранное значение как постоянный параметр сессии.
- [x] При отправке сообщений использовать режим сессии автоматически (без ручного переключателя в chat screen).
- [x] Удалить toggle из navigation bar в `ChatView`.
- [x] Отобразить текущий режим в метаданных сессии (subtitle списка сессий).

## Implementation notes

- **Backend:** `POST /api/sessions` принимает `use_knowledge_base`; мапится в `session_type` (`query_with_kb` / `empty_chat`); `GET` list/detail отдаёт `use_knowledge_base`.
- **iOS:** `KBSession.useKnowledgeBase`, `SessionKBModeStore` (UserDefaults fallback + create-time persist), toggle в `NewSessionSheet`, `ChatViewModel.useKnowledgeBase` immutable.

## Acceptance

- [x] В новом чате пользователь один раз выбирает режим KB on/off.
- [x] После открытия чата toggle в navbar отсутствует.
- [x] Поведение `send/stream` стабильно использует сохраненный режим сессии.
- [x] Значение не теряется после перезапуска приложения.
- [x] Покрыто тестами модели/VM на персистентность режима.

## Follow-up

- Вынести смену режима в “Session settings” (не входит в v1 этой задачи).
