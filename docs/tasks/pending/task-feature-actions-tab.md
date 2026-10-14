# Feature: Actions tab (Structured UI widgets / presets)

**Status:** In progress (v1 shell + jobs)  
**Priority:** Medium  
**Related:** boards `system_query_jobs`, Structured UI `action_id`, bot boards MCP

## Goal

Separate shell tab (not Overview boards): presets with info + buttons that run **actions** — cancel jobs, quick-compose photo to a chat (fuel / receipt), request geo, etc.

## Direction

- Render Structured UI documents (reuse board/chat renderer).
- Client maps `action_id` → app/system capabilities; results may compose into a bound session.
- Move **active jobs** board here (cancel already: `DELETE /api/jobs/{id}`).

## v1

- [x] Tab shell (`tab.actions` / Действия)
- [x] Jobs document via existing `BoardDetailView` + `active-jobs` / `demo-active-jobs`
- [x] Hide jobs board from Overview list (client filter)
- [x] Actions tab sections: presets board (`actions-presets`) + jobs (`active-jobs`), not mixed in one document
- [x] `compose_camera` KBAppAction + preset «Фото → питание» (static board via MCP)
- [ ] photo → fuel / geo / more presets — MCP-only copies of the same pattern

## Later

- Action builder / vault definitions (more presets without app release when only JSON changes)
- Richer camera pipelines / bound sessions by title
