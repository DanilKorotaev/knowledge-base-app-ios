# Закрепление сессий в списке чатов (iOS)

**Статус:** Delivered (2026-06-17) — фаза 1, client-only UserDefaults  
**Приоритет:** 🟡 Средний  
**Категория:** Product / UX  

**Связанные задачи:**

- [task-feature-default-voice-session.md](task-feature-default-voice-session.md)
- [task-feature-session-delete-rename.md](task-feature-session-delete-rename.md)
- Backend follow-up (фаза 2): синк pin через KB App API — отдельная задача

## Delivered

- [x] `PinnedSessionsStore` + `UserDefaultsKey.pinnedSessionIds` (JSON array, LIFO pin order)
- [x] `SessionListSorter.displayOrder` — pinned block + unpinned API order
- [x] `MainView`: prune on fetch, pin/unpin via context menu + trailing swipe, `pin.fill` icon
- [x] Удаление сессии → `pinnedStore.remove`
- [x] Поиск без client-side pin sort
- [x] `UserDefaultsKeyRegistry` category `Sessions`
- [x] Unit tests: `PinnedSessionsStoreTests`, `SessionListSorterTests`

## Acceptance (фаза 1)

- [x] Закреплённая сессия вверху основного списка (не в поиске)
- [x] Последний pin выше предыдущих; повторный pin поднимает наверх
- [x] Unpin → серверный порядок среди незакреплённых
- [x] Удаление / prune — нет призрачных pin
- [x] Локально на устройстве (без синка)

## Follow-up (фаза 2)

- [ ] Server-side `pinned_order` + merge при `loadSessions`
- [ ] Опционально: лимит pin, визуальный разделитель «Pinned»
