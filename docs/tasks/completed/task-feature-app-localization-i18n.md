# App localization (i18n): String Catalog + language override

**Status:** Completed (v1, 2026-07-05)  
**Priority:** High  
**Category:** UX / Platform

## Delivered (v1)

- [x] `SharedLocalization/Localizable.xcstrings` — English (base) + Russian
- [x] `AppLanguageStore` + `L10n` helper (UserDefaults in main app; widgets use system locale until App Group — see pending task)
- [x] Migrated voice/sync/composer/error strings from inventory
- [x] Settings → Language picker (System / English / Russian)
- [x] `environment(\.locale)` at app root
- [x] Widgets + App Intent titles via catalog
- [x] `RelativeDateTimeFormatter` for sync relative ages
- [x] Tests: `AppLanguageStoreTests`, updated `SyncStatusTests`, `VoicePipelineErrorMessageTests`
- [x] CI: `scripts/ci/check_no_hardcoded_cyrillic.sh`
- [x] Documented in `docs/DEVELOPMENT.md`

## Remaining (v2)

- [ ] Plural rules (`stringsdict`) for message counts, duration, file counts
- [ ] Localized push notification previews (server-side; see push sanitizer task)
- [ ] watchOS companion UI strings when Watch grows beyond relay status
- [ ] App Group for widget/extension language override — `task-infra-app-group-shared-defaults.md`
- [ ] `InfoPlist.xcstrings` for microphone usage descriptions (still RU in `project.yml`)
- [ ] RTL layout audit

## Acceptance (v1)

- [x] Device English → main UX in English (override or system)
- [x] Device Russian → Russian for migrated screens
- [x] App override English on Russian device → English UI
- [x] Widgets/intents use shared String Catalog; language override in app only (widget follows system locale until `task-infra-app-group-shared-defaults.md`)
