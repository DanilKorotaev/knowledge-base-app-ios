# Debug UX: quick send logs + Debug sheet gesture + log-session header

**Status:** Completed (2026-08-27)  
**Priority:** High  
**Category:** Product / Debug

## Done

- [x] `X-KB-App-Log-Session` on every API request (`LogSession.shared.id`) + backend `client_meta` logging
- [x] Toggle **Shake to send logs** (Settings Developer + Debug → Logs → Settings)
- [x] Shake → confirm → attach current `.log` to open chat composer (+ note with filename / session id)
- [x] Main session list: 3-finger swipe down → Debug menu as modal sheet

## How to use

1. Enable **Shake to send logs**.
2. Open a chat, shake phone → **Send** → log file appears in composer; send the message as usual.
3. On the session list, swipe down with three fingers → Debug sheet.
