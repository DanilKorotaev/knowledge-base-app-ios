# Push notifications: chat reply ready

**Status:** Deferred (2026-06-09) — после composer redesign; APNs не начинали.

**Master spec (Obsidian):** `Документация/Задачи/task-kb-app-push-uvedomleniya-otvet-chat.md`

## Scenario

User sends a chat message and leaves the app. When the assistant reply is saved, deliver an APNs alert. Suppress banner when the same chat is open in foreground. Tap opens that session.

## iOS checklist

- [ ] Push Notifications capability + `aps-environment`
- [ ] `UNUserNotificationCenter` permission + `registerForRemoteNotifications`
- [ ] Send `device_token` to KB App API
- [ ] `UNUserNotificationCenterDelegate`: suppress in foreground when `session_id` matches focused chat
- [ ] Deep link to session (extend `KnowledgeBaseApp` / `MainView` pattern used for voice recording)
- [ ] `ChatSessionFocusTracker` or environment value for current session id

## Backend checklist (in `knowledge-base-bot`)

- [ ] `user_devices` table + register/unregister routes
- [ ] `ApnsPushService` after assistant message persisted
- [ ] Env: `APNS_*` keys — see master spec

## MVP acceptance

- [ ] Background: push arrives with session title + reply preview
- [ ] Tap: navigates to chat with full history
- [ ] Foreground on same chat: no banner (SSE or reload handles UI)

## Depends on

- ~~[task-ux-chat-streaming-feedback.md](task-ux-chat-streaming-feedback.md)~~ → done: `docs/tasks/completed/task-ux-chat-streaming-feedback.md`
