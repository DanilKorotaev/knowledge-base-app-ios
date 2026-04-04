# KB App API: контракт в репозитории

**Status:** Done.

## Delivered

- `docs/KB_APP_API_CONTRACT.md` — канон путей и JSON для iOS ↔ FastAPI (ошибки, сессии, сообщения, вложения, голос, файлы).
- `docs/openapi/kb-app-api.yaml` — машиночитаемый subset для расширения вместе с бэкендом.
- Клиент: разбор тела `{"error":{...}}` в `KBAppAPIErrorMessage`, `LocalizedError`, `KBChangedFile` + `snake_case` ключи.

## See also

- [task-backend-kb-app-api-sync.md](../pending/task-backend-kb-app-api-sync.md) — синхронизация с сервером.
- [task-backend-kb-app-api-mvp.md](../pending/task-backend-kb-app-api-mvp.md) — этапы реализации бэкенда.
