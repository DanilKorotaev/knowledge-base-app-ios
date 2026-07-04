# Push notifications: NSE markdown guard (iOS extension)

**Status:** Backlog  
**Priority:** Low-Medium (optional defense-in-depth after backend sanitizer)  
**Depends on:** `task-feature-push-markdown-preview-sanitizer.md` (backend v1 deployed)  
**Related:** `task-feature-push-notifications-chat.md`

## Problem

Backend `preview_plain_text()` already strips markdown before APNs. An on-device pass can still help if:

- old API versions send raw markdown;
- future payloads bypass sanitizer;
- edge-case markdown slips through regex.

## Goal

Add `UNNotificationServiceExtension` that cleans notification body before display (plain text only — no rich markdown UI).

## Requires (App Store / Developer Portal)

- New extension target + bundle ID, e.g. `com.coredan.KnowledgeBaseApp.NotificationService`
- App ID + provisioning profile for extension (embedded in main app IPA)
- **No** new App Store Connect app listing — same TestFlight app, new build with embedded extension
- Backend: `"mutable-content": 1` in `aps` when extension is live

## iOS scope

- [ ] Notification Service Extension target in `project.yml` / XcodeGen
- [ ] Shared sanitizer logic (Swift) or duplicate lightweight stripper — idempotent, no network
- [ ] Enable `mutable-content` only after extension ships (coordinate with backend flag)

## Backend scope (small)

- [ ] Optional flag in `build_chat_reply_payload` to set `aps.mutable-content = 1` when NSE deployed

## Acceptance

- [ ] If body still contains `**`, backticks, or `[text](url)` artifacts, NSE presents cleaned plain text.
- [ ] Tap → session deep link unchanged.
- [ ] Extension does not block delivery on timeout (fallback to original payload).

## Not in scope

- `UNNotificationContentExtension` (custom expanded UI)
- Rich bold/italic in system banner
