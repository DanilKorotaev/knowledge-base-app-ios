# Analysis: embed HealthKit sync into Knowledge Base App

**Status:** Draft pending product OK (2026-08-31)  
**Priority:** Medium  
**Category:** Product / Health  
**Canonical write-up (RU, full):** knowledge-base vault note `Документация/Задачи/анализ-healthkit-vnutri-kb-app.md`  
**Auth epic (separate):** vault `Документация/Задачи/эпик-kb-app-avtorizaciya-multiuser.md`

## Summary

Optional Health module in the Knowledge Base app: HealthKit → JSON → **KB App API** (server writes into configurable relative folder under the vault and syncs to Nextcloud). **No WebDAV / Nextcloud credentials in the iOS client.**

Full login / multi-user auth is a **separate** epic; first Health MVP may use shared Bearer + `users.health_data_relative` (or prefs API).

## Depends on (Apple)

- HealthKit + background delivery on `com.coredan.KnowledgeBaseApp`
- Match profile refresh
- Privacy usage strings

## Backend (same change set as client)

- `GET/PATCH /api/me/settings` (at least `health_data_relative`)
- `POST /api/health/sync/files` (write + server-side NC sync)
- Path validation (relative only)

## Not in this epic

- Share Extension
- Full auth / OAuth / multi-user vault provisioning (other vault note)
- Client-side WebDAV

## After approval

Split into implementation tasks in `knowledge-base-bot` + this repo.
