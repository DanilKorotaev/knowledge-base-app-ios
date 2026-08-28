# UX: Optimistic Structured UI user bubble + retry

**Status:** pending (backlog)  
**Vault:** `Документация/Задачи/task-structured-ui-next.md`

## Problem

Сейчас `[UI]` user stub появляется **после** ответа `ui-events`. При долгом агенте пользователь не видит, что тап зарегистрирован. При ошибке сети нет явного retry на уровне UI-события.

## Proposal

- Optimistic append `[UI] <label>` в ленту сразу после тапа / submit
- При успехе — заменить на финальные messages с сервера
- При ошибке — оставить bubble с кнопкой **Retry** (повторить тот же `action_id` / `values`)
- Не дублировать с bottom pending spinner (один индикатор ожидания)

## Done when

- [ ] `ChatViewModel.sendStructuredUIEvent` — optimistic user line + rollback on failure
- [ ] Retry на failed UI event (reuse `FailedSendRetry` pattern или аналог)
- [ ] Unit tests на state machine
- [ ] Manual QA: slow agent, airplane mode mid-request

## Notes

Отложено по решению 2026-08-28 — сначала fullscreen/media polish.
