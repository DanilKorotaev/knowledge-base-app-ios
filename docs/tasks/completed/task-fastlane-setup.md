# Task: Fastlane (test + beta)

**Completed:** 2026-04-04

## Summary

- Added `Gemfile` / `Gemfile.lock` (Fastlane ~> 2.227).
- `fastlane/Fastfile`: lane `test` (scan + xccov gate), lane `beta` (Match + gym + TestFlight).
- `Appfile`, `Matchfile` with env-driven `APP_IDENTIFIER` / `MATCH_GIT_URL`.
- CI switched to `bundle exec fastlane test`.
- `deploy-testflight.yml` for manual TestFlight uploads.
- Documentation: `docs/FASTLANE.md`.

## Follow-up

- Run `fastlane match appstore` locally once the private cert repo exists.
- Set GitHub Secrets and run **Deploy TestFlight**.
