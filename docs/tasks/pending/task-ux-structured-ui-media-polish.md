# UX: Structured UI media nodes polish (image / file / link)

**Status:** pending  
**Vault:** `Документация/Задачи/task-structured-ui-next.md`  
**Scope:** iOS + agent prompts (quality, not hardcoded demos)

## Problem

P1 ноды (`image`, `link`, `file`, `divider`) приняты в сессии 206 — «пойдёт», но есть шероховатости:

- агент иногда выдумывал `download_url` → 404 (`guide.pdf`); iOS fix частично помог (public https без auth)
- placeholder «битая картинка» без retry / понятного текста
- file preview: сырой JSON в alert (`{"detail":"Not Found"}`) вместо локализованной ошибки
- нет прогресса загрузки на `image` / `file` при медленной сети
- нет связи с **реальными** attachment id из сообщения сессии (агент должен резолвить, не фантазировать)

## Done when

- [ ] User-facing ошибки для image/file (локализация, без сырого API JSON)
- [ ] Retry tap на failed image
- [ ] Документировать для агента: `url` для публичных картинок; `download_url` только из контекста чата
- [ ] (Опционально) API helper: зарегистрировать vault-файл → `download_url` для SUI
- [ ] Manual QA checklist в vault

## Out of scope

- Hardcoded «media demo» экраны на бэкенде (удалены из mock flow)

## References

- `StructuredUIResourceFetcher.swift`, `StructuredUIMediaNodes.swift`
- `agent/structured_ui_agent_prompt.md`, `reply_suggest.py`
