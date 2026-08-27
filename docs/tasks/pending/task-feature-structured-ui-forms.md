# Feature: Structured UI forms (deferred submit)

**Status:** done (code)  
**Branch:** `main` (iOS) / `develop` (bot)  
**Vault:** `Документация/Задачи/task-structured-ui-next.md`

## Scope

- Nodes: `checkbox`, `radio_group`, `select` (+ multi), `text_field`
- Local draft until `button.submit == true` → `ui-events.values`
- Mock: welcome → Open form → Submit
- Agent prompt updated for forms

## Manual

1. Interactive UI (icon) → Open form / or agent form  
2. Toggle fields without new chat lines  
3. Submit → one `[UI] …` summary + next screen
