# Offline attachments: disk cache and selective cleanup

**Status:** Done  
**Parent:** `task-feature-offline-mode-cache-sync.md`  
**Depends on:** `task-feature-offline-cache-foundation.md`  
**Priority:** High

## Goal

Keep viewed attachments available offline and provide user control over storage.

## Scope

- Add `AttachmentDiskCache` with metadata index:
  - key/path, file size, MIME type, message/session reference, last access.
- Integrate with `KBAttachmentLoader`:
  - return local file/data on hit;
  - download + persist + return on miss.
- Implement size policy:
  - configurable soft limit;
  - LRU cleanup when limit is exceeded.
- Add Settings > Offline cache:
  - total cache size and counters;
  - cached attachments list;
  - single delete and multi-select delete;
  - clear all cache (destructive confirm).

## Out of scope

- Upload queue for unsent files/messages.
- Smart content dedup across sessions/devices.

## Acceptance

- [x] Previously opened image/voice attachments are accessible offline.
- [x] User can inspect cache size and entries.
- [x] User can delete one item and clear all cache.
- [x] LRU cleanup works when cache exceeds configured limit.
- [x] Unit tests for cache hit/miss/eviction + settings actions.

## Implementation notes (2026-06-19)

- `FileAttachmentDiskCache` — 256 MB soft limit, JSON index, LRU eviction.
- `CachingAttachmentLoader` — read-through wrapper used by `MainView.makeAttachmentLoader()`.
- `OfflineCacheManagementView` — Settings → Offline → manage list, swipe delete, clear all.
