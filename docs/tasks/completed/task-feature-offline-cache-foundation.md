# Offline foundation: persistent cache for sessions and messages

**Status:** Done (v1 — file-backed cache + cache-first read paths)  
**Parent:** `task-feature-offline-mode-cache-sync.md`  
**Priority:** High

## Goal

Build production-grade local persistence so the app can render sessions/chats without network.

## Scope

- Add local persistent stores (SQLite/SwiftData) for:
  - sessions (`id`, `title`, `messageCount`, `updatedAt`);
  - messages (`id`, `sessionId`, `role`, `content`, `contentFormat`, `createdAt`);
  - attachment metadata needed for offline rendering.
- Introduce repository interfaces (`SessionCacheStore`, `MessageCacheStore`) and DI-ready implementations.
- Add cache bootstrap paths:
  - `MainView` reads cached sessions first;
  - `ChatViewModel` reads cached messages first.
- Add remote-to-local upsert path after successful fetch.

## Out of scope

- Sync badges/refresh banners UX.
- Attachment disk file caching policy and management UI.
- Offline outgoing queue/retry.

## Acceptance

- [x] Existing data is visible after relaunch with network off.
- [x] Opening a previously used chat works without API call success.
- [x] Local data updates after successful online refresh.
- [x] Unit tests for store CRUD/upsert/ordering + repository mapping.

## Implementation notes (2026-06-19)

- `FileOfflineCacheStore` — JSON in Application Support (`sessions.json`, `messages/{id}.json`).
- `MainView.loadSessions()` — cache-first, no blocking spinner when cache exists; network failure keeps cache.
- `ChatViewModel.load()` — bootstrap from cache; `apply` / `loadOlder` write-through after API success.

## Implementation notes (2026-06-20)

- Cache file stores the **union** of all messages loaded via pagination (merge on persist, no shrink on refresh).
- Bootstrap restores the **full** cached window, not `pageSize` (5) only.
- Offline `loadOlder` prepends remaining messages from the cache file when the network is down.
