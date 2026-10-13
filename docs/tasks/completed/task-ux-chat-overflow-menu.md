# UX: Chat overflow menu (kebab)

**Status:** Done (manual QA: rename / KB / SUI / Share)  
**Priority:** Medium  
**Depends on:** lazy new chat (KB toggle needs a home after sheet removal)

## Goal

Toolbar **Menu** on chat screen for session actions currently only on the list context menu / Structured UI button.

## v1

- [x] Rename (reuse `RenameSessionSheet` + `updateSession`; local title for drafts)
- [x] Use Knowledge Base toggle (mutable for draft + existing)
- [x] Structured UI preference + start flow in the same overflow menu
- [x] Share chat link (public read-only URL)
- [x] Unit tests: `ChatViewModelOverflowMenuTests`

## Later

- Pin / archive / delete
