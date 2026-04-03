# Fastlane + Match + TestFlight

**Status:** In progress (Fastlane in repo; Match + ASC secrets — вручную)

## Done in repo

- `Gemfile` / `Gemfile.lock`, `fastlane/Fastfile` lanes `test` + `beta`, `Appfile`, `Matchfile`
- CI runs `bundle exec fastlane test`
- Manual workflow: `.github/workflows/deploy-testflight.yml` (`workflow_dispatch`)

## Осталось сделать (ты)

- Apple Developer + App Store Connect app record (реальный bundle ID вместо `com.example.KnowledgeBaseApp`)
- Приватный GitHub-репо для Match + `fastlane match appstore` локально
- GitHub Secrets: `MATCH_*`, `ASC_*` (см. [docs/FASTLANE.md](../../FASTLANE.md))
- Первый успешный **Deploy TestFlight** из Actions

## Notes

- Тот же Apple Developer Program, что и для HealthSync; сертификаты **отдельные** под bundle ID этого приложения.
