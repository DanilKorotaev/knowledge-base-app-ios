# Multi-account switch + per-account offline cache

**Статус:** ✅ Done  
**Приоритет:** 🟡 Средний  
**Категория:** Auth / Offline  

## Цель

Хранить несколько сессий на устройстве; при переключении аккаунта офлайн-кэш не сбрасывается. Кэш аккаунта удаляется только при полном «Выйти».

## Чеклист

- [x] `SavedAccountsStore` — Keychain list + active pointer
- [x] `AuthSessionStore`: switch / add account / sign-out (wipe only signed-out scope)
- [x] Settings UI: saved accounts, add account, sign out footer
- [x] Offline cache already keyed by `host/u<id>` (`OfflineCacheScope`)
- [x] Unit test: two accounts survive switch; sign-out drops one then the other
