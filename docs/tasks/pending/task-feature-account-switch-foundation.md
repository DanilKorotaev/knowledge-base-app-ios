# Foundation: multi-account cache keys (UI later)

**Статус:** 📋 Planned  
**Приоритет:** 🟢 Low / later  
**Категория:** Auth  
**Depends on:** `task-feature-auth-logout-cache-per-user`

## Цель

Не строить UI переключения аккаунтов сейчас. Заложить: Keychain/cache могут хранить несколько `(server, userId)` профилей; active account pointer. UI switch — отдельная задача после стабильного auth.

## Чеклист

- [ ] Document storage layout for multi-profile
- [ ] No UI; single active session only in v1
- [ ] Ensure logout/cache task keys don’t paint into a corner
