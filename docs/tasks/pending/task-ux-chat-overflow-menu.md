# UX: Chat overflow menu (kebab)

**Status:** Code done on `feature/chat-overflow-menu` (manual QA pending)  
**Priority:** Medium  
**Depends on:** lazy new chat (KB toggle needs a home after sheet removal)

## Goal

Toolbar **Menu** on chat screen for session actions currently only on the list context menu / Structured UI button.

## v1

- [x] Rename (reuse `RenameSessionSheet` + `updateSession`; local title for drafts)
- [x] Use Knowledge Base toggle (mutable for draft + existing)
- [x] Structured UI preference + start flow in the same overflow menu
- [x] Unit tests: `ChatViewModelOverflowMenuTests`

## Later

- Pin / archive / delete
- Share chat link (`task-feature-shared-chat-public-link` in bot)
