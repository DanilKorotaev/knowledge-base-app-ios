# Auth: logout + offline cache scoped per user

**Статус:** 📋 Planned  
**Приоритет:** 🟡 Средний  
**Категория:** Auth / Offline  
**Depends on:** `task-feature-auth-login-register`

## Цель

Logout чистит сессию; offline cache и attachment disk cache ключуются по `serverURL + userId`, чтобы не смешивать данные аккаунтов (задел под account switch).

## Чеклист

- [ ] Sign out: clear Keychain tokens, revoke refresh (API), clear in-memory clients
- [ ] Cache directory / keys include user id
- [ ] Settings: manage cache (существующий UI) работает в per-user scope
- [ ] Tests for cache isolation between two fake user ids
