# Changelog

All notable changes to the Knowledge Base iOS app are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Marketing version (`CFBundleShortVersionString`) comes from the root [`VERSION`](VERSION) file.
Build number (`CFBundleVersion`) is the CI run number (`GITHUB_RUN_NUMBER`) and is listed in [`docs/RELEASES.md`](docs/RELEASES.md).

On each successful **main → TestFlight** deploy, CI auto-bumps **PATCH** (unless a minor/major was requested), folds commit subjects + `[Unreleased]` into a new section below, then tags `ios/v*`. See [`docs/RELEASE_PROCESS.md`](docs/RELEASE_PROCESS.md).

## [Unreleased]

## [1.0.19] - 2026-08-29

### Fixed

- Clearer Structured UI media errors and path fallback
- Restore missingLoader for API paths without attachment loader

## [1.0.18] - 2026-08-28

### Changed

- Update Structured UI task statuses after P2/P3 ship

### Fixed

- Improve Structured UI markdown, stepper, and progress UX

## [1.0.17] - 2026-08-28

### Added

- Structured UI P3 blocks and multiline buttons

### Fixed

- Resolve P3 test compile errors

## [1.0.16] - 2026-08-28

### Added

- Zoomable fullscreen images and SUI media polish
- Add Structured UI P2 blocks

### Changed

- Add Structured UI media coverage tests

### Fixed

- Stabilize Structured UI media coverage tests

## [1.0.15] - 2026-08-28

### Changed

- Add Structured UI fullscreen and media polish tasks

## [1.0.14] - 2026-08-28

### Fixed

- Load public Structured UI media without KB API auth

## [1.0.13] - 2026-08-27

### Added

- Structured UI image, link, file, and divider nodes

## [1.0.12] - 2026-08-27

### Fixed

- Keep Interactive UI toolbar icon visible when Off

## [1.0.11] - 2026-08-27

### Added

- Interactive UI preference toggle and read-only history

## [1.0.10] - 2026-08-27

### Changed

- Release packaging / TestFlight upload.

## [1.0.9] - 2026-08-27

### Fixed

- Keep Structured UI waiting cue only in chat pending bubble

## [1.0.8] - 2026-08-27

### Added

- Structured UI MVP — models, panel, ui-events client
- Structured UI forms with deferred submit

### Changed

- Structured UI contract, OpenAPI, and i18n strings
- Document structured UI agent mode env flags
- Include Structured UI sources in XcodeGen after main rebase
- Mark Structured UI XCTest acceptance done after rebase

### Fixed

- Structured UI waiting progress and toolbar icon

## [1.0.7] - 2026-08-27

### Fixed

- Hide chat tab bar and expand RU/EN localization

## [1.0.6] - 2026-08-27

### Fixed

- Keep shake-to-send toggle only in log settings

## [1.0.5] - 2026-08-27

### Added

- Tab shell with Chats and Settings, remove list mic bar

## [1.0.4] - 2026-08-27

### Added

- Shake-to-send debug logs and log-session API header

### Fixed

- Include debug quick-actions sources in XcodeGen project
- MainActor log toggle, MainView type-check, isolate voice tests

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

[Unreleased]: https://github.com/DanilKorotaev/knowledge-base-app-ios/compare/ios/v1.0.19...HEAD
[1.0.19]: https://github.com/DanilKorotaev/knowledge-base-app-ios/releases/tag/ios/v1.0.19
[1.0.18]: https://github.com/DanilKorotaev/knowledge-base-app-ios/releases/tag/ios/v1.0.18
[1.0.17]: https://github.com/DanilKorotaev/knowledge-base-app-ios/releases/tag/ios/v1.0.17
[1.0.16]: https://github.com/DanilKorotaev/knowledge-base-app-ios/releases/tag/ios/v1.0.16
[1.0.15]: https://github.com/DanilKorotaev/knowledge-base-app-ios/releases/tag/ios/v1.0.15
[1.0.14]: https://github.com/DanilKorotaev/knowledge-base-app-ios/releases/tag/ios/v1.0.14
[1.0.13]: https://github.com/DanilKorotaev/knowledge-base-app-ios/releases/tag/ios/v1.0.13
[1.0.12]: https://github.com/DanilKorotaev/knowledge-base-app-ios/releases/tag/ios/v1.0.12
[1.0.11]: https://github.com/DanilKorotaev/knowledge-base-app-ios/releases/tag/ios/v1.0.11
[1.0.10]: https://github.com/DanilKorotaev/knowledge-base-app-ios/releases/tag/ios/v1.0.10
[1.0.9]: https://github.com/DanilKorotaev/knowledge-base-app-ios/releases/tag/ios/v1.0.9
[1.0.8]: https://github.com/DanilKorotaev/knowledge-base-app-ios/releases/tag/ios/v1.0.8
[1.0.7]: https://github.com/DanilKorotaev/knowledge-base-app-ios/releases/tag/ios/v1.0.7
[1.0.6]: https://github.com/DanilKorotaev/knowledge-base-app-ios/releases/tag/ios/v1.0.6
[1.0.5]: https://github.com/DanilKorotaev/knowledge-base-app-ios/releases/tag/ios/v1.0.5
[1.0.4]: https://github.com/DanilKorotaev/knowledge-base-app-ios/releases/tag/ios/v1.0.4
[1.0.3]: https://github.com/DanilKorotaev/knowledge-base-app-ios/releases/tag/ios/v1.0.3
[1.0.2]: https://github.com/DanilKorotaev/knowledge-base-app-ios/releases/tag/ios/v1.0.2
[1.0.1]: https://github.com/DanilKorotaev/knowledge-base-app-ios/releases/tag/ios/v1.0.1
[1.0.0]: https://github.com/DanilKorotaev/knowledge-base-app-ios/releases/tag/ios/v1.0.0
