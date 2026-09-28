# Feature: Archive boards from Overview

**Status:** In progress  
**Related (KB notes):** `Документация/Задачи/task-boards-archive.md`  
**Related (bot):** archive/restore routes + MCP tools

## Goal

Hide boards from Overview without deleting definitions; restore later (append to end).

## Scope

- [x] `BoardsAPIClient` archive / restore / fetchArchived
- [x] Swipe + context menu → Archive on Overview
- [x] `BoardsArchiveView` + restore swipe
- [x] EN/RU strings
- [ ] Manual check after API deploy

## Acceptance

- [ ] Archived board disappears from Overview
- [ ] Restore returns board at end of list
