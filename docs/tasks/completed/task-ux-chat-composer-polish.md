# Chat composer: polish (follow-up)

**Status:** Completed (2026-07-05)  
**Master spec (archived):** `Документация/Задачи/выполненные/task-kb-app-chat-composer-telegram-ux.md`  
**Completed core:** `docs/tasks/completed/task-ux-chat-composer-telegram.md`

## Delivered

- [x] Quick Look for non-image file attachments (composer strip + message thread)
- [x] Client-side attachment count / size limits before send (5 files, 25 MB each — aligned with KB App API)
- [x] Gallery / Files menu disabled when attachment cap reached
- [x] Unit tests: `ComposerAttachmentLimitsTests`, `AttachmentPreviewURLResolverTests`, `KBMessageTests.documentAttachments`

## Remaining

- [ ] RU localization for composer strings (UI mostly EN) — see `task-feature-app-localization-i18n.md`
- [ ] UI test: sheet actions add to strip without network

## Not in scope

- Watch / widget one-shot send — keep existing flow without full composer draft
