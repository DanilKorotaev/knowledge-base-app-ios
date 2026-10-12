# UX: Highlight submitted Structured UI form values in history

**Status:** done (2026-08-29)  
**Vault:** `Документация/Задачи/task-structured-ui-next.md`

## Shipped

- Bot: on `ui-events` with `values`, bake into previous form message `structured_ui`
- iOS: `StructuredUIFormDraft.applying` + stub client bake
- Read-only panels: accent highlight / static value display for selected fields

## References

- `kb_app_api/structured_ui/apply_values.py`
- `KnowledgeBaseApp/Models/KBStructuredUI.swift` (`StructuredUIFormDraft.applying`)
- `KnowledgeBaseApp/Views/Chat/StructuredUIRenderer.swift`
