# Auth: Server URL → login / register → session

**Статус:** ✅ Done  
**Приоритет:** 🔴 Высокий  
**Категория:** Auth  
**Эпик:** vault `эпик-kb-app-avtorizaciya-multiuser`  
**Backend:** `knowledge-base-bot` `task-api-auth-nextcloud-users`  
**Test against:** `https://kbapp-staging.coredan.ru` only

## Цель

Убрать ручной shared Bearer из UX. Onboarding: server URL → sign in / register (если сервер `open_signup`) → access+refresh в Keychain. Interceptor: 401 → refresh → re-login.

## Чеклист

- [x] Login / Register screens
- [x] Keychain: access + refresh (shared with Share Extension group)
- [x] `KBHTTPTransport` 401 → refresh retry (auth paths excluded)
- [x] `must_change_password` → forced change UI
- [x] Settings: account + sign out; raw token behind advanced toggle
- [ ] Point TestFlight/debug at staging during epic
- [x] Contract sync with backend auth endpoints (`/api/auth/*`)
- [x] Unit tests (`AuthAPIClientTests`) + UI test (`AuthLoginUITests`)
