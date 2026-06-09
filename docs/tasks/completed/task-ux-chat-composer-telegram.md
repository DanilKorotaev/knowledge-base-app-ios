# Chat composer: Telegram-style input bar

**Completed:** 2026-06-09  
**Commits:** `019cb4b` (Phase A UI), `97432ff` (compose client + composite bubble fixes)

**Master spec:** `Документация/Задачи/task-kb-app-chat-composer-telegram-ux.md`  
**Backend:** `knowledge-base-bot/docs/tasks/completed/task-api-chat-composer-multipart.md`

**E2E:** prod Session 109 — 2 images + 3 voice + text → one user message, one assistant SSE reply.

## Goal

Redesign chat input: centered `TextField`, `+` menu (attachments), mic + send on bottom row. Voice transcribes into the field (append). Attachments preview above field. Single Send posts everything via compose API.

## Delivered

### Models

- [x] `PendingAttachment`, `PendingVoiceClip`, `ChatComposerDraft`
- [x] `ChatComposerSendPlanner` — legacy single-item routes + `.compose` for multi-send

### Views

- [x] `ChatComposerView` — rounded panel, text on top, `+` / mic / send row
- [x] `+` menu — Gallery (multi), Camera, Files
- [x] `ComposerAttachmentStripView`, `ComposerFileChipView`, `ComposerVoiceChipView`
- [x] `ImagePreviewSheet` — full screen on thumbnail tap
- [x] Keyboard dismiss — swipe on scroll + tap message area
- [x] `+` icon tint matches mic (`.primary`)

### Voice integration

- [x] Transcribe → append to `composerDraft.text` + `PendingVoiceClip`
- [x] Skip `PostRecordingReviewSheet` when chat open (`deferToComposer`)
- [x] Mic + send always visible (send disabled when draft empty)

### Send

- [x] Text only → `streamTextMessage`
- [x] Single file / single voice → legacy endpoints
- [x] Multi-file, file+text, mixed → `streamComposedMessage` (`POST …/messages/compose`)
- [x] Optimistic user bubble with local attachment previews (`file://`)
- [x] Composite bubble layout — 2-column image grid, voice rows with collapsed transcription, no duplicate text

### KB toggle

- [x] Navigation toolbar compact toggle

### Related fixes (same release)

- [x] `TerminalSanitizer` — strip ANSI `[?25h` from assistant text (client-side; backend also filters new replies)

## Follow-up (optional polish)

- [ ] Quick Look for non-image file attachments in thread
- [ ] Client-side attachment count / size limits before send
- [ ] UI test: sheet actions add to strip without network

## Tests

- [x] `ChatComposerDraftTests`, `KBMessageTests` (composite bubble), `TerminalSanitizer` via renderer test

## Depends on

- ~~Streaming UX~~ → `task-ux-chat-streaming-feedback.md`
- ~~Compose API~~ → `task-api-chat-composer-multipart.md`
