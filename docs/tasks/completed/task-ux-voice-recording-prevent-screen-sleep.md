# Voice: keep screen awake while recording

**Status:** Completed (2026-08-27)  
**Priority:** High  
**Category:** Product / Voice UX

**Related:** [task-feature-voice-recording-pause-resume-locked.md](../completed/task-feature-voice-recording-pause-resume-locked.md)

## Problem

In Low Power Mode (short auto-lock), the display dims while the user records a locked voice message hands-free.

## Solution

`UIApplication.isIdleTimerDisabled` via `ScreenIdleTimerLock` while AV capture is actively recording; restored on pause, cancel, and finish.

## Acceptance

- [x] Screen stays on during hold-to-talk and locked recording
- [x] Screen may dim again while recording is paused
- [x] Idle timer restored after send, cancel, or failed start (release on Send tap, not after merge)
- [x] Unit test with mock idle timer lock
- [x] Verified on device (Low Power Mode / auto-lock): stays awake while recording; OK after Send
