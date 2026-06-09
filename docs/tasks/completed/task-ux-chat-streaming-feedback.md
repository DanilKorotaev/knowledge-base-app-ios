# Chat UX: processing indicator, streaming bubble, typing animation

**Completed:** 2026-06-09  
**Commit:** `dc5610e` (typewriter reveal), `6a0a501` (phases + spinner), `77a0392` (plain-text stream bubble)

**Master spec (Obsidian):** `Документация/Задачи/task-kb-app-chat-streaming-ux.md`

## Delivered

### State

- `AssistantReplyPhase`: `idle | waiting | streaming(String) | finalizing(String)`
- `.waiting` сразу после optimistic user bubble, до первого SSE delta
- Стрим-UI не сбрасывается до `reloadLatest` после завершения typewriter-reveal

### Views

- `TypingIndicatorView` — три точки «печатает»
- `AssistantPendingBubbleView` — спиннер + «Обрабатываю…»
- `StreamingAssistantBubbleView` — plain text + typewriter при батчевых delta
- `StreamTextRevealState` — reveal без перезапуска на каждый chunk

### Voice / shared chat

- `AssistantReplyPhaseNotification` — фазы из mic-flow в открытый чат
- `waitForStreamRevealAnimation()` перед `reloadLatest`

### Logging

- `[streaming] delta #N` / `done chunks=N` в Chat-теге (по умолчанию выключен)

### Backend (отдельный репо, `develop`)

- SSE `{"status":"processing"}` сразу после POST
- Split delta ~48 символов + delay; PTY для cursor-agent на macOS
- nginx: `proxy_buffering off` (шаблон в Nextcloud; VPS — проверить деплой)

## Acceptance (проверено на prod)

- [x] Спиннер до первого delta
- [x] Текст нарастает с точками «печатает» (typewriter при батче с сервера)
- [x] Финальное сообщение из БД без мигания
- [x] Ошибка send не сбрасывает optimistic user bubble

## Follow-up

- Настоящий посимвольный стрим с сервера (Cursor CLI + nginx без буферизации) — меньше задержка до первого delta (~15 s с KB sync)
- Фильтр ANSI escape (`\u001b[?25h`) в ответах cursor-agent

## Supersedes

- iOS: `docs/tasks/pending/task-ux-chat-streaming-feedback.md` (этот файл — archived copy in pending removed)
