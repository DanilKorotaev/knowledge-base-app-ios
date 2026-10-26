# Auth: logout + offline cache scoped per user

**Статус:** ✅ Done  
**Приоритет:** 🟡 Средний  
**Категория:** Auth / Offline  
**Depends on:** `task-feature-auth-login-register`

## Цель

Logout чистит сессию; offline cache и attachment disk cache ключуются по `serverURL + userId`, чтобы не смешивать данные аккаунтов (задел под account switch).

## Чеклист

- [x] Sign out: clear Keychain tokens, revoke refresh (API), clear in-memory clients
- [x] Cache directory / keys include user id
- [x] Settings: manage cache (существующий UI) работает в per-user scope
- [x] Tests for cache isolation between two fake user ids
