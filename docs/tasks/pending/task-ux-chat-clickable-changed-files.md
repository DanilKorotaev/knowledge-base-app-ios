# Chat UX: clickable changed files from assistant reply

**Status:** Backlog  
**Priority:** Medium-High  
**Related (bot):** `knowledge-base-bot/docs/tasks/pending/task-ux-clickable-file-links-in-response.md`

## Problem

Assistant can mention changed file paths in message text, but in iOS chat user cannot open those paths directly from the reply.

## Goal

Provide an actionable "open changed files" flow in chat, first via a robust MVP (separate block/list), then evolve to true inline clickable paths.

## Iteration plan

### Iteration 1 (MVP, Telegram-like)

- Show a dedicated block under assistant message: "Changed files in this reply".
- Each item is tappable and opens existing `FileDiffView` (via `ChangedFilesView` route or direct payload).
- If exact per-reply mapping is unavailable from API, show top recent changed files with clear "Recent changes" label.
- Add fallback action button in assistant bubble: "Open changed files".

### Iteration 2 (target UX)

- Render clickable file references inline in assistant text (markdown/html enrichment).
- Tap opens file diff/share link directly.
- Preserve readable formatting for plain text and markdown blocks.

## Required API/contract support

- Extend message payload with optional structured field, e.g.:
  - `related_changed_files: [{ file_id, path, change_kind, before_preview, after_preview }]`
  - or minimal `{ file_id, path }` for open-in-diff.
- If backend cannot bind files to exact reply yet, define endpoint for "recent changed files since timestamp/message id".

## iOS scope

- Message model extension for reply-level changed file references.
- UI component in chat bubble for clickable list (MVP) and inline links (v2).
- Routing to `FileDiffView`.
- Graceful fallback when references are missing or stale.

## Acceptance (MVP)

- [ ] After assistant reply with file changes, user sees a tappable list/button in chat.
- [ ] Tap opens diff/details screen for selected file.
- [ ] If mapping is not available, fallback opens recent changes with clear labeling.
- [ ] UX does not block regular message rendering.

## Acceptance (v2)

- [ ] File paths in assistant text are clickable inline.
- [ ] Click target opens specific file diff/share destination.
