# UX: Paste / drop clipboard images as composer attachments

**Status:** Backlog  
**Priority:** Medium  
**Category:** Product / Chat UX  
**Related:** [`task-feature-share-extension-compose.md`](task-feature-share-extension-compose.md) (share-in is separate; this is **inside** the main app composer)

## Problem

Messengers often let you:

1. Long-press a screenshot / copied image and **drag** it into another app, or  
2. Open the composer and use **Paste**, which inserts an **image attachment** (not only plain text).

Knowledge Base composer today: text paste works via the field; there is no first-class “paste image → attachment chip” / drop-on-composer path.

## Goal

In the main app chat composer (and optionally chat scroll area):

- Paste image data from `UIPasteboard` → add as `PendingAttachment` (same pipeline as photo picker / share-merge).  
- Support drag-and-drop of images onto the composer (iOS drop delegates / `DropDelegate`) where the system provides image/file providers.  
- Respect existing attachment limits, MIME allow-list, and draft persistence.

## Scope

- [ ] Detect pasteboard image (and maybe file URL) when user pastes into composer or taps an explicit **Paste** affordance if the text field doesn’t expose image paste  
- [ ] Convert to staged file in draft store (same as other attachments)  
- [ ] Drag-and-drop onto composer strip / text field  
- [ ] Optional: banner “Image on clipboard — tap to attach” when becoming active with image on pasteboard (nice-to-have; can defer)  
- [ ] Unit tests for pasteboard → `PendingAttachment` mapping  
- [ ] Manual: screenshot → copy → paste in composer; Photos copy → paste; drag from Photos (if supported on device)

## Out of scope

- Share Extension (system Share sheet) — other task  
- Pasting rich HTML as formatted bubbles  
- Video clipboard (unless already allowed by composer limits)

## Research notes

- `UIPasteboard.general.image` / `UIImage` vs item providers (`public.image`, `public.png`)  
- SwiftUI `TextField` paste may only take strings — may need `UITextView` bridge or intercept `paste:` via `UIPasteControl` / toolbar button  
- iOS 16+ `PasteButton` / paste permission prompts — handle gracefully  

## Acceptance

- [ ] Pasting a copied screenshot/image adds an attachment chip, not only ignored paste  
- [ ] Draft survives leave/reopen chat  
- [ ] Over-limit paste shows the same limit UX as picking too many files  
