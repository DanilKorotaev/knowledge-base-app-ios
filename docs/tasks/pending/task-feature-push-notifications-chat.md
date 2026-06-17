# Push notifications: chat reply ready

**Status:** In progress — MVP implemented (2026-06-17).

**Master spec (Obsidian):** `Документация/Задачи/task-kb-app-push-uvedomleniya-otvet-chat.md`

## Scenario

User sends a chat message and leaves the app. When the assistant reply is saved, deliver an APNs alert. Suppress banner when the same chat is open in foreground. Tap opens that session.

## iOS checklist

- [x] Push Notifications capability + `aps-environment`
- [x] `UNUserNotificationCenter` permission + `registerForRemoteNotifications`
- [x] Send `device_token` to KB App API
- [x] `UNUserNotificationCenterDelegate`: suppress in foreground when `session_id` matches focused chat
- [x] Deep link to session (`knowledgebase://session/{id}`)
- [x] `ChatSessionFocusTracker` for current session id

## Backend checklist (in `knowledge-base-bot`)

- [x] `user_devices` table + register/unregister routes
- [x] `ApnsPushService` after assistant message persisted
- [x] Env: `APNS_*` keys — see master spec

## MVP acceptance

- [ ] Background: push arrives with session title + reply preview (E2E on device)
- [ ] Tap: navigates to chat with full history
- [ ] Foreground on same chat: no banner (SSE or reload handles UI)

## Depends on

- ~~[task-ux-chat-streaming-feedback.md](task-ux-chat-streaming-feedback.md)~~ → done: `docs/tasks/completed/task-ux-chat-streaming-feedback.md`
