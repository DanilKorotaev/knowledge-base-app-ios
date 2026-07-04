# Push notifications: markdown-safe preview (backend)

**Status:** Completed (backend v1, 2026-07-05)  
**Priority:** Medium-High  
**Related:** `task-feature-push-notifications-chat.md`  
**Follow-up (iOS, needs new extension bundle ID):** `task-feature-push-nse-markdown-guard.md`

## Problem

Assistant replies are markdown-first. Push preview body may contain raw markdown markers (`**bold**`, backticks, list markers), which looks noisy in iOS notification banners/list.

## Delivered (backend v1 — no App Store / bundle ID changes)

- [x] `strip_markdown_for_push()` + extended `preview_plain_text()` in `kb_app_api/apns_push_service.py`
- [x] Strips HTML, emphasis, code fences/inline code, markdown links → label, list/blockquote prefixes
- [x] Collapses whitespace; keeps truncation with ellipsis
- [x] Unit tests in `kb_app_api/tests/test_push_notifications.py`

**Deploy:** Mac Mini `kb-app-api` on `develop` (same as other API fixes).

## Out of scope (separate task)

- Notification Service Extension (`mutable-content`, defense-in-depth on device) — see pending NSE task.

## Acceptance (backend v1)

- [x] Push preview body does not contain raw markdown markers for common assistant responses.
- [x] Markdown links readable as text labels (without URL markup in preview).
- [x] Long previews truncated with ellipsis.
- [x] Existing push delivery/tap/open session flow unchanged.
