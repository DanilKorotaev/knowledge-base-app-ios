# Chat UX: collapsible changed-files list under assistant reply

**Status:** Completed (2026-08-27)  
**Priority:** Medium  
**Category:** Product / Chat UX

**Related:** [task-ux-chat-clickable-changed-files.md](task-ux-chat-clickable-changed-files.md)

## Problem

`related_changed_files` / “Recent changed files” under an assistant bubble can list many paths and cover a large share of the chat viewport, hiding the reply the user just got while composing the next message.

## Goal

Keep the list available, but **collapsed by default**. A header row with title, count, and chevron expands/collapses the file rows with a short animation.

## Implementation

- `ChangedFilesListView` in `RichMessageBubbleView.swift`: `@State isExpanded = false`, header `Button` + rotating `chevron.down`, file rows only when expanded.

## Acceptance

- [x] Default: only header (title + count + chevron), reply text stays visible
- [x] Tap expands to full list; tap again collapses
- [x] Expand/collapse animated
