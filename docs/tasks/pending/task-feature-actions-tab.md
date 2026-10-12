# Feature: Actions tab (Structured UI widgets / presets)

**Status:** Backlog (epic)  
**Priority:** Medium  
**Related:** boards `system_query_jobs`, Structured UI `action_id`, bot boards MCP

## Goal

Separate shell tab (not Overview boards): presets with info + buttons that run **actions** — cancel jobs, quick-compose photo to a chat (fuel / receipt), request geo, etc.

## Direction

- Render Structured UI documents (reuse board/chat renderer).
- Client maps `action_id` → app/system capabilities; results may compose into a bound session.
- Move **active jobs** board here (cancel already: `DELETE /api/jobs/{id}`).

## v1

- Tab shell + jobs document
- 1–2 config-driven actions (e.g. “photo → fuel chat”)

## Later

- Action builder / vault definitions (zero-deploy like boards)
- Alerts, geo, camera pipelines as first-class action results
