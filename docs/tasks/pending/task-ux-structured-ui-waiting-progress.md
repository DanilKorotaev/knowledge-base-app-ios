# Feature: Structured UI waiting / progress UX

**Status:** in progress  
**Branch:** `feature/structured-ui-mvp`  
**Vault:** `Документация/Задачи/task-structured-ui-next.md`

## Problem

While `POST …/ui-events` runs (agent can take tens of seconds), buttons use `.disabled` → dark grey with no spinner — unlike normal chat pending bubble.

## Done when

- [x] Active panel shows ProgressView + localized “updating…”
- [x] Chat list shows `AssistantPendingBubbleView` while `isSendingUIEvent`
- [x] Only the latest structured UI message gets the in-flight visual (history panels stay normal)
- [x] Buttons block taps without system disabled greying
- [x] Drop in-panel spinner — keep only bottom pending bubble (less dual-loader noise)
- [ ] Manual check on device / TestFlight

## Notes

No backend change required for this UX fix.
In-panel spinner removed 2026-08-27; waiting cue is only the chat pending bubble.