# Feature: Overview / Boards tab + Structured UI renderer for board documents

**Status:** In progress  
**Related (KB notes):** `Документация/Задачи/task-kb-dashboards-platform.md` (этап A placeholder + renderer; API later)  
**Related (bot):** `knowledge-base-bot/docs/tasks/pending/task-feature-boards-api-and-cache.md`

## Goal

Ship the **Overview** tab next to Chats / Health / Settings. List boards from `GET /api/boards`, open a detail screen that renders a Structured UI document (`metric` / `table` + existing nodes). Client stays domain-agnostic (no vault paths).

## Scope (this change)

- [x] `TabView` tab **Overview** (`tab.overview`) → `BoardsTabView`
- [x] Models: `KBBoard`, `KBBoardDetail`, list cell preview
- [x] `BoardsAPIClientProtocol` + stub + `URLSessionBoardsAPIClient`
- [x] Demo catalog fallback when API returns **404** (backend not shipped yet)
- [x] Detail screen reuses `StructuredUIPanelView` (read-only)
- [x] Structured UI nodes: `metric`, `table`
- [x] Unit tests (decode, stub, HTTP, view models, view hosting)
- [x] EN/RU localization
- [ ] Manual TestFlight check of Overview tab + demo boards

## Out of scope (later)

- Boards CRUD / DB / vault compute DSL / remote proxy / active jobs system board (backend tasks)
- Agent tools `boards.create` / refresh hooks
- Charts

## Acceptance

- [x] `bundle exec fastlane test` green with coverage above gate (~38% vs 35%)
- [ ] TestFlight: Overview tab visible; demo KPI + jobs boards open
