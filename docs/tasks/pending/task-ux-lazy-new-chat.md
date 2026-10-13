# UX: Lazy new chat (no create sheet)

**Status:** Code done on `feature/lazy-new-chat` (manual QA pending)  
**Priority:** High  
**Related:** overflow menu (`task-ux-chat-overflow-menu.md`), session display title (bot)

## Goal

Toolbar **+** opens an empty chat immediately. No `POST /api/sessions` until the first send (text / voice / attachments). Back without send leaves no session in the list.

## Behavior

- Draft session id: `draft:<uuid>` (client-only, not listed).
- Default `use_knowledge_base=true` (toggle later in chat overflow menu).
- Title on create: truncated first message text, or empty → server fallback.
- On promote: migrate composer draft / KB mode / in-flight stores; notify session list refresh.

## Checklist

- [x] `KBSession.makeLocalDraft` / `isLocalDraft`
- [x] MainView `+` → push draft (no `NewSessionSheet`)
- [x] `ChatViewModel.ensureServerSessionIfNeeded` before send
- [x] `load()` / `refresh()` no-op for drafts
- [x] Unit tests: `ChatViewModelLazyDraftTests` (4 passed)
