# Auth: Server URL → login / register → session

**Статус:** 📋 Planned  
**Приоритет:** 🔴 Высокий  
**Категория:** Auth  
**Эпик:** vault `эпик-kb-app-avtorizaciya-multiuser`  
**Backend:** `knowledge-base-bot` `task-api-auth-nextcloud-users`  
**Test against:** `https://kbapp-staging.coredan.ru` only

## Цель

Убрать ручной shared Bearer из UX. Onboarding: server URL → sign in / register (если сервер `open_signup`) → access+refresh в Keychain. Interceptor: 401 → refresh → re-login.

## Чеклист

- [ ] Login / Register screens
- [ ] Keychain: access + refresh (shared with Share Extension group)
- [ ] `KBRequestInterceptor` refresh flow
- [ ] `must_change_password` → forced change UI
- [ ] Settings: account, no raw token paste in App Store path
- [ ] Point TestFlight/debug at staging during epic
- [ ] Contract sync with backend auth endpoints
