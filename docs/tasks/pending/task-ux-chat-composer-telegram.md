# Chat composer: Telegram-style input bar

**Status:** In progress — Phase A done; Phase B compose client wired (needs backend deploy)

**Master spec:** `Документация/Задачи/task-kb-app-chat-composer-telegram-ux.md`  
**Backend:** `knowledge-base-bot/docs/tasks/pending/task-api-chat-composer-multipart.md`

## Goal

Redesign chat input: centered `TextField`, paperclip (attachments), mic by default; send button when there is text and/or draft attachments. Voice transcribes into the field (append). Attachments preview above field. Single Send posts everything — requires new API.

## Phase A delivered (2026-06-09)

### Models

- [x] `PendingAttachment` (id, localURL, kind: image/file, filename, mime)
- [x] `PendingVoiceClip` (id, audioURL, transcriptionSegment)
- [x] `ChatComposerDraft` on `ChatViewModel`
- [x] `ChatComposerSendPlanner` — routes to legacy API or surfaces unsupported combo

### Views

- [x] `ChatComposerView` — replaces `inputBar` in `ChatView`
- [x] `AttachmentPickerSheet` — File / Camera / Gallery (multi)
- [x] `ComposerAttachmentStripView` — thumbnails + remove
- [x] `ComposerFileChipView` / `ComposerVoiceChipView`
- [x] `ImagePreviewSheet` — full screen on thumbnail tap

### Voice integration

- [x] On transcribe complete: append to `composerDraft.text`
- [x] Queue `PendingVoiceClip`; loader near field while transcribing
- [x] Skip `PostRecordingReviewSheet` when chat open (`deferToComposer`)
- [x] Second recording appends text + second clip

### Send

- [x] Text only → `streamTextMessage`
- [x] Single file → `sendAttachment`
- [x] Single voice → `streamVoiceMessage`
- [x] Multi-file / file+text / mixed → `streamComposedMessage` (`POST …/messages/compose`)

### KB toggle

- [x] Moved to navigation toolbar (compact icon toggle)

## Remaining (Phase B+)

- [ ] Deploy backend `POST …/messages/compose` to prod
- [ ] Quick Look for non-image files
- [ ] Attachment count / size limits

## Tests

- [x] Unit: `ChatComposerDraftTests` — send planner + append transcription
- [ ] UI: sheet actions add to strip without network call

## Depends on

- ~~[task-ux-chat-streaming-feedback.md](task-ux-chat-streaming-feedback.md)~~ → done
- Push notifications deferred — see `task-feature-push-notifications-chat.md`
