# SWR sync UX: stale-while-revalidate status on sessions and chat

**Status:** Done  
**Parent:** `task-feature-offline-mode-cache-sync.md`  
**Depends on:** `task-feature-offline-cache-foundation.md`  
**Priority:** High

## Goal

Make cache-first behavior transparent to users with clear sync state and non-blocking refresh.

## Scope

- Implement sync state model for list + chat:
  - `.idle`, `.refreshing`, `.offline(lastSyncedAt)`, `.failed(error, lastSyncedAt)`.
- Add coordinator (`SyncCoordinator`) for refresh triggers:
  - first open,
  - pull-to-refresh,
  - app became active.
- Sessions screen UX:
  - show cached list immediately;
  - show compact status row/badge while refresh runs.
- Chat screen UX:
  - show cached messages immediately;
  - show thread-level refresh/offline state.
- Keep UI interactive while refresh is in progress if local data exists.

## Out of scope

- Detailed cache settings/management screens.
- Inline clickable changed-file links in assistant messages.

## Acceptance

- [x] Cached list and chat open instantly, network refresh runs in background.
- [x] User sees explicit status transitions (refreshing/offline/error/updated).
- [x] Offline mode no longer shows only hard error when cache exists.
- [x] Unit tests for sync state transitions.

## Implementation notes (2026-06-19)

- `SyncStatus` + `SyncStatusBannerView` — compact status row (RU copy).
- `NetworkPathMonitor` — `NWPathMonitor` for proactive offline detection.
- `MainView` / `ChatViewModel` — `.refreshing` → `.upToDate` / `.offline` / `.failed`.
- Triggers: `.refreshable`, `scenePhase == .active`, toolbar refresh.
