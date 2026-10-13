# Infra: Share Extension signing + App Group (+ Keychain)

**Status:** Done (repo) — portal/Match assumed ready by owner  
**Priority:** High  
**Category:** Infra / Signing  
**Unblocks:** Share feature (implemented)  
**Related:** [`task-infra-app-group-shared-defaults.md`](task-infra-app-group-shared-defaults.md)

## Repo work completed

- [x] Entitlements: main app + Share → App Group + Keychain access group; Widget already had App Group
- [x] `project.yml`: `KnowledgeBaseShareExtension` target, embed in `KnowledgeBaseApp`
- [x] Fastlane Match list already included Share; CI Manual signing now pins Share profile
- [x] Docs: `docs/FASTLANE.md`, `docs/DEVELOPMENT.md`
- [x] `verify_entitlements.sh` / `check_version_bump.sh` include Share

## Owner checklist (portal)

See vault note `Документация/Задачи/чеклист-apple-developer-kb-app-match.md`. Identifiers used in code:

| Item | Value |
|------|-------|
| Share Extension App ID | `com.coredan.KnowledgeBaseApp.Share` |
| App Group | `group.com.coredan.KnowledgeBaseApp` |
| Keychain access group | `$(AppIdentifierPrefix)com.coredan.KnowledgeBaseApp` (`66C9VGAZR5.com.coredan.KnowledgeBaseApp` at runtime) |
