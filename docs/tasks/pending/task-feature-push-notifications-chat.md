# Push notifications: chat reply ready

**Status:** MVP implemented (2026-06-17). **Acceptance E2E on device** — open checklist below.

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
- [x] Log all push interactions with full payload (`PushNotificationLogger`, `29536f4`)

## Backend checklist (in `knowledge-base-bot`)

- [x] `user_devices` table + register/unregister routes
- [x] `ApnsPushService` after assistant message persisted (`deliver_chat_reply_push` with timeout, `0f031fd`)
- [x] Env: `APNS_*` keys on mini (key outside TCC-protected paths)

## MVP acceptance

- [ ] Background: push arrives with session title + reply preview (formal device run; APNs 200 verified on mini 2026-06-17)
- [ ] Tap: navigates to chat with full history
- [ ] Foreground on same chat: no banner (SSE or reload handles UI)
- [ ] Logout unregisters device token on server

## V2 (not MVP)

- Server-side SSE awareness to skip redundant push
- Badge / unread model
- Push on `processing_error`

## Depends on

- ~~[task-ux-chat-streaming-feedback.md](task-ux-chat-streaming-feedback.md)~~ → done: `docs/tasks/completed/task-ux-chat-streaming-feedback.md`
