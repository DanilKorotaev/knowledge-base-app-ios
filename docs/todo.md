# TODO

## In progress

- [ ] [Push: ответ готов](tasks/pending/task-feature-push-notifications-chat.md) — MVP в коде; приёмка E2E на устройстве
- [ ] [Apple Watch: complication](tasks/pending/task-feature-watch-app-voice.md) — приёмка на Watch / TestFlight

## Planned

### Docs / design

- [x] Docs refresh (ARCHITECTURE, CONTRACT boards/presets, UI.md, DOCUMENTATION_MAP) — 2026-10-26
- [ ] [SwiftLint cleanup epic](tasks/pending/task-epic-swiftlint-cleanup.md) — soft CI green; re-enable strict rules + Swift 6 Sendable
- [ ] Figma MCP connect + first Settings frames (see [UI.md](UI.md))
- [ ] Live screenshots → redesign Settings / account switch (native iOS)
- [ ] Mac mini: install Figma Desktop + Open Figma MCP plugin (`~/Projects/tools/open-figma-mcp-plugin`) so KB App API `cursor-agent` can use the local bridge (WS 127.0.0.1:18765)

### Integration

- [ ] E2E: расширить `KnowledgeBaseAPIE2ETests` — SSE, voice, compose — [testing/E2E.md](testing/E2E.md)
- [ ] Ручной прогон: сессии, чат, SSE, вложения, голос, files, пагинация, **account switch**
- [ ] [Синхронизация контракта](tasks/pending/task-backend-kb-app-api-sync.md) — ongoing

### Product backlog (pending folder)

- [ ] [Share Extension → compose](tasks/pending/task-feature-share-extension-compose.md)
- [ ] [Composer paste clipboard images](tasks/pending/task-ux-composer-paste-clipboard-attachments.md)
- [ ] [Push NSE markdown guard](tasks/pending/task-feature-push-nse-markdown-guard.md)
- [ ] Chat / composer bugfixes under `docs/tasks/pending/task-bug-*`
- [ ] HealthKit / structured-ui polish tasks as prioritized

### Auth / multi-user

- [x] Login / register, logout+cache, push after login, account switch — see `docs/tasks/completed/`

## Completed

See [completed.md](completed.md) and `docs/tasks/completed/`.
