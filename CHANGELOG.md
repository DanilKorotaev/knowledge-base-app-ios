# Changelog

All notable changes to the Knowledge Base iOS app are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Marketing version (`CFBundleShortVersionString`) comes from the root [`VERSION`](VERSION) file.
Build number (`CFBundleVersion`) is the CI run number (`GITHUB_RUN_NUMBER`) and is listed in [`docs/RELEASES.md`](docs/RELEASES.md).

On each successful **main → TestFlight** deploy, CI auto-bumps **PATCH** (unless a minor/major was requested), folds commit subjects + `[Unreleased]` into a new section below, then tags `ios/v*`. See [`docs/RELEASE_PROCESS.md`](docs/RELEASE_PROCESS.md).

## [Unreleased]

## [1.0.3] - 2026-08-27

### Fixed

- Restore idle timer immediately on voice Send

## [1.0.2] - 2026-08-27

### Added

- Keep screen awake during voice recording

## [1.0.1] - 2026-08-27

### Added

- Automatic SemVer patch releases on each successful main→TestFlight deploy (commit message → changelog, no PR required).
- Settings → About with copyable `version (build)` for support.
- Deploy pipeline: `prepare_release.py`, post-upload release commit, and `ios/v*` git tag.

### Changed

- Marketing version synced from root `VERSION` file across app, widget, and watch targets.
- Info.plist version fields use `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)` instead of hard-coded literals.

## [1.0.0] - 2026-08-26

Baseline SemVer for TestFlight builds that previously shipped as marketing `1.0` with only a rising build number.

### Added

- Client version/build/OS headers on every KB App API request (`X-KB-App-*`).
- SemVer source of truth (`VERSION`), changelog, and release process docs.

### Fixed

- Resume in-flight assistant reply after background / leaving chat (no false “connection lost”).
- Hard send failures: Retry bar instead of restoring the draft into the composer.
- Message copy sheet uses a plain text view so partial selection pastes as text.

[Unreleased]: https://github.com/DanilKorotaev/knowledge-base-app-ios/compare/ios/v1.0.3...HEAD
[1.0.3]: https://github.com/DanilKorotaev/knowledge-base-app-ios/releases/tag/ios/v1.0.3
[1.0.2]: https://github.com/DanilKorotaev/knowledge-base-app-ios/releases/tag/ios/v1.0.2
[1.0.1]: https://github.com/DanilKorotaev/knowledge-base-app-ios/releases/tag/ios/v1.0.1
[1.0.0]: https://github.com/DanilKorotaev/knowledge-base-app-ios/releases/tag/ios/v1.0.0
