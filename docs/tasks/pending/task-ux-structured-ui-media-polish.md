# UX: Structured UI media nodes polish (image / file / link)

**Status:** partial (2026-08-28)  
**Vault:** `Документация/Задачи/task-structured-ui-next.md`

## Done

- [x] User-facing ошибки (`StructuredUIErrorMessage`)
- [x] Retry tap на failed `image`
- [x] Agent: не выдумывать attachment URLs (prompt)
- [x] Public https без KB auth для remote images

## Open

- [ ] Прогресс загрузки на `image` / `file` при медленной сети
- [ ] (Опционально) API helper: vault-файл → `download_url` для SUI
- [ ] Manual QA checklist

## References

- `StructuredUIResourceFetcher.swift`, `StructuredUIMediaNodes.swift`
