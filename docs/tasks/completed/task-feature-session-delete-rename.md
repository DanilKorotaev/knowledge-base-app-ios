# Удаление и переименование сессий (iOS)

**Статус:** ✅ Выполнено  
**Дата завершения:** 2026-06-01  
**Backend:** [task-api-session-crud-extensions.md](../../../knowledge-base-bot/docs/tasks/completed/task-api-session-crud-extensions.md)

## Реализовано

- `deleteSession` / `updateSession` в `KnowledgeBaseAPIClientProtocol` + HTTP + stub store.
- `MainView`: swipe Delete, context menu Rename, confirm alert, optimistic delete + rollback.
- `RenameSessionSheet`; сброс `VoiceRoutingContext.activeSessionId` при удалении открытой сессии.
- Контракт и OpenAPI обновлены.

## Acceptance

- [x] Удалённая сессия исчезает из списка; на сервере `status=deleted`.
- [x] Переименованная сессия отображается с новым заголовком после refresh.
- [x] Ошибки API через alert «Session».
