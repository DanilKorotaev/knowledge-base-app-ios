# Chat composer: Telegram-style input bar

**Status:** Pending

**Master spec:** `Документация/Задачи/task-kb-app-chat-composer-telegram-ux.md`  
**Backend blocker:** `knowledge-base-bot/docs/tasks/pending/task-api-chat-composer-multipart.md`

## Goal

Redesign chat input: centered `TextField`, paperclip (attachments), mic by default; send button when there is text and/or draft attachments. Voice transcribes into the field (append). Attachments preview above field. Single Send posts everything — requires new API.

## Current (`ChatView`)

- Photo + camera + paperclip + mic + field + send in one row; KB toggle above.
- Each attachment triggers immediate `sendAttachment()` (full pipeline).
- Voice uses `PostRecordingReviewSheet` and immediate `streamVoiceMessage`.

## Target layout

```
[ attachment previews strip ]
[ TextField ............... ] [clip] [mic | send]
```

- `mic` when draft is “empty” for send purposes; `send` when text non-empty OR attachments OR voice clips queued.
- Recording UI: keep `MicRecordControl` in `safeAreaInset` (existing gestures).

## iOS tasks

### Models

- [ ] `PendingAttachment` (id, localURL, kind: image/file, filename, mime)
- [ ] `PendingVoiceClip` (id, audioURL, transcriptionSegment)
- [ ] `ChatComposerDraft` on `ChatViewModel` or dedicated observable

### Views

- [ ] `ChatComposerView` — replaces `inputBar` in `ChatView`
- [ ] `AttachmentPickerSheet` — File / Camera / Gallery (multi)
- [ ] `ComposerAttachmentStripView` — thumbnails + remove
- [ ] `ComposerFileChipView` — non-image preview
- [ ] `ImagePreviewSheet` — full screen on thumbnail tap

### Voice integration

- [ ] On transcribe complete: append to `draft.text` (separator if needed)
- [ ] Queue `PendingVoiceClip`; loader near field while `isTranscribing`
- [ ] Skip auto-send from `confirmPostRecordUpload` when chat composer owns draft (route via composer callback)
- [ ] Second recording appends text + second clip

### Send

- [ ] `sendComposedMessage` on `ChatAPIClientProtocol` (after backend lands)
- [ ] Until then: document fallback behavior in UI tests / feature flag

### KB toggle

- [ ] Decide placement (toolbar vs compact row) per master spec §9

## Tests

- [ ] Unit: send button enabled when text OR attachments OR voice clips
- [ ] Unit: append transcription preserves existing draft text
- [ ] UI: sheet actions add to strip without network call

## Acceptance

See master spec §7.

## Depends on

- `knowledge-base-bot/docs/tasks/pending/task-api-chat-composer-multipart.md` for full single-send
- Optional parallel: [task-ux-chat-streaming-feedback.md](task-ux-chat-streaming-feedback.md) for reply UX after send
