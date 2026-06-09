# Fastlane + Match + TestFlight

**Completed:** 2026-06-10  
**Delivery:** CI/CD deploys builds to TestFlight (GitHub Actions + Match + ASC secrets configured).

## Delivered

- `Gemfile` / `Gemfile.lock`, `fastlane/Fastfile` lanes `test` + `beta`, `Appfile`, `Matchfile`.
- CI: `bundle exec fastlane test` on every push/PR.
- Deploy workflow: `.github/workflows/deploy-testflight.yml` — automated TestFlight uploads.
- Apple Developer + App Store Connect app record; Match certificates for app bundle ID.
- GitHub Secrets: `MATCH_*`, `ASC_*`, `KBAPP_*` (see [FASTLANE.md](../../FASTLANE.md), [API_CONFIGURATION.md](../../API_CONFIGURATION.md)).

## Notes

- Same Apple Developer Program as HealthSync; certificates are separate per bundle ID.
- See also [task-fastlane-setup.md](task-fastlane-setup.md) (initial Fastlane wiring).
