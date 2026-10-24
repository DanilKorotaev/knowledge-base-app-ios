# Push: register device after login (multi-user)

**Статус:** 📋 Planned  
**Приоритет:** 🟡 Средний  
**Категория:** Push  
**Backend:** `task-api-push-devices-per-user`  
**Depends on:** `task-feature-auth-login-register`

## Цель

APNs device token регистрировать **после** успешного login от имени юзера; на logout — unregister. Не использовать shared Bearer.

## Чеклист

- [ ] Hook: login success → `POST /api/devices`
- [ ] Logout → `DELETE /api/devices/{token}`
- [ ] Token refresh / re-register on APNs token rotate while logged in
- [ ] Staging: verify push tied to correct account
