# Chat UX: clickable changed files from assistant reply

**Status:** Completed (MVP, 2026-07-05)  
**Priority:** Medium-High  
**Related (bot):** `knowledge-base-bot/docs/tasks/pending/task-ux-clickable-file-links-in-response.md`

## Problem

Assistant can mention changed file paths in message text, but in iOS chat user cannot open those paths directly from the reply.

## Goal

Provide an actionable "open changed files" flow in chat, first via a robust MVP (separate block/list), then evolve to true inline clickable paths.

## Delivered (MVP)

- [x] Dedicated block under assistant message: "Changed files in this reply" / "Recent changed files"
- [x] Each item opens `FileDiffView` via `NavigationLink`
- [x] Fallback button "Open changed files" → `ChangedFilesView` when API mapping missing
- [x] `KBMessage.relatedChangedFiles` + backend enrichment (`related_changed_files`, `related_changed_files_source`)

**iOS:** `RichMessageBubbleView.swift`, `KBMessage.swift`  
**Backend:** `kb_app_api/message_enrichment.py`, serializers

## Remaining (v2)

- [ ] Render clickable file references inline in assistant text (markdown/html enrichment)
- [ ] Tap opens file diff/share link directly in prose

## Acceptance (v2)

- [ ] File paths in assistant text are clickable inline.
- [ ] Click target opens specific file diff/share destination.
