# Offline mode: sessions, chat history, attachment cache management

**Status:** Done (v1)  
**Priority:** High (UX/performance)  
**Related UX reference:** Telegram-like stale-while-revalidate flow ("show cached now, refresh in background")

## Problem

Current iOS app behavior is online-first:

- Session list is loaded from API; without network user may get an error/empty state.
- Chat messages are reloaded from API and are not persisted as an offline history cache.
- Attachments (image/voice/file previews) are fetched on demand and not managed as a durable cache.
- There is no visible sync status per screen ("updating...", "outdated", "last synced").
- There is no UI to inspect cache size, list cached attachments, and delete entries selectively.

## Desired behavior (target UX)

- On app open, show cached sessions immediately (no blocking spinner when local data exists).
- Start background refresh right away; merge updates and refresh UI when network data arrives.
- In chat, show cached messages instantly, then update in background (same stale-while-revalidate model).
- Keep downloaded attachments locally so previously viewed content remains available offline.
- Show sync state on both screens:
  - sessions list: refreshing indicator + last sync timestamp/error badge;
  - chat screen: per-thread refresh indicator + offline/outdated hint.
- Provide cache management:
  - total cache size;
  - list of cached attachments with metadata (name, size, last access/session);
  - selective delete;
  - "clear all cache" action.

## Proposed scope (v1)

### 1) Persistent local storage for sessions/messages

- Add a local repository layer (`SessionCacheStore`, `MessageCacheStore`) backed by SQLite/SwiftData.
- Cache entities: sessions, messages, message attachments, sync metadata (`lastSyncedAt`, source version/hash if available).
- Read path:
  - `MainView` loads cached sessions first;
  - `ChatViewModel` loads cached message window first.
- Write path:
  - on successful API fetch, upsert cache and publish updated view models.

### 2) SWR sync orchestration

- Introduce `SyncCoordinator` for stale-while-revalidate behavior:
  - state machine: `.idle`, `.refreshing`, `.failed(error, lastSyncedAt)`, `.offline(lastSyncedAt)`;
  - scope for sessions and per-session messages.
- Trigger refresh on:
  - initial screen open;
  - pull-to-refresh;
  - app returning active.
- Keep UI interactive during refresh when cached data exists.

### 3) Attachment disk cache

- Add `AttachmentDiskCache` (sandbox directory with index DB or manifest).
- `KBAttachmentLoader` flow:
  - return local file if cache hit;
  - otherwise download, store, and return local URL/data.
- Cache policies:
  - soft size limit + LRU cleanup;
  - per-item metadata (byte size, mime type, session/message link, last access).

### 4) Cache management UI

- Add Settings section: "Offline cache".
- Show:
  - total occupied size;
  - counts (sessions/messages/attachments cached).
- Add screens/actions:
  - list attachments with preview metadata;
  - delete one attachment;
  - multi-select delete;
  - clear all cache with destructive confirmation.

### 5) Sync status UX

- Sessions screen:
  - subtle top status row (refreshing/offline/error/updated X min ago).
- Chat screen:
  - inline status near thread top or under navigation title.
- Keep status text concise and localized (EN now, RU follow-up if localization scope is expanded).

## Execution split (recommended)

- [x] `task-feature-offline-cache-foundation.md` — persistent cache data layer (sessions/messages).
- [x] `task-ux-swr-sync-status-sessions-chat.md` — cache-first + refresh status UX.
- [x] `task-feature-offline-attachment-disk-cache-management.md` — attachment disk cache + settings management UI.

## Not in scope (v1)

- Full offline send queue with delayed upload/retry of outgoing messages.
- Conflict-free merge editing of locally mutated messages.
- Cross-device cache sync semantics.
- Server-driven diff protocol (client can start with full-fetch + local upsert).

## Technical notes against current code

- `MainView.loadSessions()` currently overwrites `sessions` from remote API only; needs cache-first read path.
- `ChatViewModel.load()` / `reloadLatestWindow()` currently rely on network fetch only; needs local cache bootstrap.
- `URLSessionKnowledgeBaseAPIClient` attachment loading currently returns network bytes directly; needs disk caching adapter.
- Existing `InMemoryKBStore` is stub/demo-only and cannot act as production offline persistence.

## Acceptance criteria

- [x] With network disabled after prior usage, app opens and shows sessions + previously opened chats from cache.
- [x] Attachments that were previously opened (image/voice) are viewable/playable offline.
- [x] On reconnect, list/chat refresh automatically and status transitions from offline/stale to up-to-date.
- [x] User can view total cache size and cached attachments list in Settings.
- [x] User can delete a single cached attachment and clear all cache.
- [x] Unit tests for repository/cache logic + at least one UI/integration smoke for cache management flow.

## Dependencies / follow-ups

- Optional backend optimization later: incremental sync cursors (`updated_since`) for sessions/messages.
- Coordinate with `task-backend-kb-app-api-sync.md` if API adds delta endpoints.
