# Infra: Share Extension signing + App Group (+ Keychain)

**Status:** Backlog — **blocked on Apple Developer / Match** (owner provides IDs & regenerates profiles)  
**Priority:** High  
**Category:** Infra / Signing  
**Unblocks:** [`task-feature-share-extension-compose.md`](task-feature-share-extension-compose.md)  
**Related:** [`task-infra-app-group-shared-defaults.md`](task-infra-app-group-shared-defaults.md) (widgets language; **same App Group**)

## Why

Share Extension cannot read the main app sandbox. Drafts today: `Application Support/KBComposerDrafts`. Without an **App Group**, “Add to draft” from Share cannot appear in the main chat composer.

Send-from-extension needs the API bearer token → **Keychain Access Group** shared with the main app (or users re-enter token in the extension — unacceptable).

## What you need to create / refresh (portal + Match)

Suggested identifiers (adjust if naming differs):

| Item | Suggested value |
|------|-----------------|
| Share Extension App ID | `com.coredan.KnowledgeBaseApp.Share` |
| App Group | `group.com.coredan.KnowledgeBaseApp` (reuse for widgets + share + future NSE) |
| Keychain access group | e.g. `$(AppIdentifierPrefix)com.coredan.KnowledgeBaseApp` (same group on app + share) |

### Checklist for owner

- [ ] Register App ID `com.coredan.KnowledgeBaseApp.Share` (capability: App Groups; Keychain Sharing; Microphone **only if** voice-in-extension is approved)
- [ ] Create/enable App Group `group.com.coredan.KnowledgeBaseApp`
- [ ] Attach App Group to:
  - [ ] `com.coredan.KnowledgeBaseApp`
  - [ ] `com.coredan.KnowledgeBaseApp.Widget` (already planned)
  - [ ] `com.coredan.KnowledgeBaseApp.Share`
- [ ] Enable Keychain Sharing on main app + Share App IDs (same access group)
- [ ] Regenerate provisioning profiles (Match):  
  `bundle exec fastlane match appstore --force` including the new Share identifier  
  (certs usually unchanged; profiles must include the new App ID + entitlements)
- [ ] GitHub / CI secrets: add `SHARE_APP_IDENTIFIER` (or extend Match `app_identifier` list in Fastfile the same way as Widget/Watch)
- [ ] Confirm App Store Connect still has **one** iOS app; Share is only an embedded extension

## Repo work (after portal is ready)

- [ ] Entitlements: main app + Share (+ Widget) → App Group; Keychain group on app + Share  
- [ ] `project.yml`: Share target, embed in `KnowledgeBaseApp`  
- [ ] Fastlane Match / `beta` lane: sign Share extension  
- [ ] Docs: `docs/FASTLANE.md`, `docs/DEVELOPMENT.md`  
- [ ] Extend [`task-infra-app-group-shared-defaults.md`](task-infra-app-group-shared-defaults.md) App ID list to include Share (same group)

## Acceptance

- [ ] Local + CI archive embeds Share Extension with valid profile  
- [ ] App Group container writable from Share and readable from main app  
- [ ] Main app can read auth token from shared Keychain access group (smoke test)  
