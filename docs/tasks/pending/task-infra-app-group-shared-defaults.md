# App Group: shared defaults (widgets + extensions)

**Status:** Backlog  
**Priority:** Medium  
**Blocked by:** Apple Developer setup (App Group ID + provisioning profile refresh)  
**Related:** `task-feature-app-localization-i18n.md`, `task-feature-widgets-app-intents.md`

## Problem

Language override in Settings is stored in app `UserDefaults`. **Widgets and extensions cannot read it** — they only follow the device system locale until a shared container exists.

Other cross-target data may also benefit later (default session title on widgets, pending counts, etc.).

## Goal

Add App Group without breaking current TestFlight signing flow.

## Scope

- [ ] Register App Group `group.com.coredan.KnowledgeBaseApp` in Apple Developer Portal
- [ ] Enable App Groups on App IDs:
  - `com.coredan.KnowledgeBaseApp`
  - `com.coredan.KnowledgeBaseApp.Widget`
- [ ] Regenerate provisioning profiles (`bundle exec fastlane match appstore --force` — certificates usually unchanged)
- [ ] Entitlements: main app + iOS widget extension
- [ ] `AppLanguageStore`: read/write `UserDefaults(suiteName:)` with fallback to `.standard`
- [ ] Verify widget labels follow Settings language override
- [ ] Document in `docs/FASTLANE.md` + `docs/DEVELOPMENT.md`

## Out of scope (for now)

- watchOS targets (companion uses separate bundle; evaluate separately)
- Migrating unrelated prefs into the group

## Acceptance

- [ ] Settings → English on Russian device → iOS home-screen widget strings in English
- [ ] TestFlight build signs without manual entitlement hacks
- [ ] No regression in main app language picker
