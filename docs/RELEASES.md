# iOS releases

Mapping of marketing SemVer ↔ TestFlight build ↔ git tag.

Rows are written by `scripts/ci/prepare_release.py` during Deploy TestFlight and finalized (build column) after a successful upload.

| Version | Build (CI) | Git tag | Date | Notes |
|---------|------------|---------|------|-------|
| 1.0.31 | 144 | `ios/v1.0.31` | 2026-09-01 | Composer height with attachments, L10n sync progress, chat open perf |
| 1.0.30 | 143 | `ios/v1.0.30` | 2026-09-01 | Match archive progress callback signature for CI build |
| 1.0.29 | 141 | `ios/v1.0.29` | 2026-09-01 | Table row height, composer text field, restore 72% columns |
| 1.0.28 | 140 | `ios/v1.0.28` | 2026-09-01 | Expand Health export and fix chat composer rendering |
| 1.0.27 | 139 | `ios/v1.0.27` | 2026-09-01 | Split Health sync UX, ZIP export, and attachment limit 10 |
| 1.0.26 | 138 | `ios/v1.0.26` | 2026-09-01 | Preserve HealthKit entitlements through XcodeGen in CI |
| 1.0.25 | 137 | `ios/v1.0.25` | 2026-09-01 | Handle missing HealthKit authorization before sync |
| 1.0.24 | 136 | `ios/v1.0.24` | 2026-09-01 | Expand Health module coverage above CI threshold |
| 1.0.23 | 132 | `ios/v1.0.23` | 2026-08-31 | TestFlight release |
| 1.0.22 | 130 | `ios/v1.0.22` | 2026-08-31 | Fix cache preview test for UTType jpeg extension. |
| 1.0.21 | 128 | `ios/v1.0.21` | 2026-08-31 | Fix cache age helper and run XcodeGen automatically in CI. |
| 1.0.20 | 126 | `ios/v1.0.20` | 2026-08-29 | Highlight submitted Structured UI values in history |
| 1.0.19 | 124 | `ios/v1.0.19` | 2026-08-29 | Restore missingLoader for API paths without attachment loader |
| 1.0.18 | 122 | `ios/v1.0.18` | 2026-08-28 | Improve Structured UI markdown, stepper, and progress UX |
| 1.0.17 | 120 | `ios/v1.0.17` | 2026-08-28 | Resolve P3 test compile errors |
| 1.0.16 | 118 | `ios/v1.0.16` | 2026-08-28 | Stabilize Structured UI media coverage tests |
| 1.0.15 | 114 | `ios/v1.0.15` | 2026-08-28 | Add Structured UI fullscreen and media polish tasks |
| 1.0.14 | 113 | `ios/v1.0.14` | 2026-08-28 | Load public Structured UI media without KB API auth |
| 1.0.13 | 112 | `ios/v1.0.13` | 2026-08-27 | Structured UI image, link, file, and divider nodes |
| 1.0.12 | 111 | `ios/v1.0.12` | 2026-08-27 | Keep Interactive UI toolbar icon visible when Off |
| 1.0.11 | 110 | `ios/v1.0.11` | 2026-08-27 | Interactive UI preference toggle and read-only history |
| 1.0.10 | 109 | `ios/v1.0.10` | 2026-08-27 | TestFlight release |
| 1.0.9 | 108 | `ios/v1.0.9` | 2026-08-27 | Keep Structured UI waiting cue only in chat pending bubble |
| 1.0.8 | 107 | `ios/v1.0.8` | 2026-08-27 | Structured UI forms with deferred submit |
| 1.0.7 | 105 | `ios/v1.0.7` | 2026-08-27 | Hide chat tab bar and expand RU/EN localization |
| 1.0.6 | 104 | `ios/v1.0.6` | 2026-08-27 | Keep shake-to-send toggle only in log settings |
| 1.0.5 | 103 | `ios/v1.0.5` | 2026-08-27 | Tab shell with Chats and Settings, remove list mic bar |
| 1.0.4 | 102 | `ios/v1.0.4` | 2026-08-27 | MainActor log toggle, MainView type-check, isolate voice tests |
| 1.0.3 | 97 | `ios/v1.0.3` | 2026-08-27 | Restore idle timer immediately on voice Send |
| 1.0.2 | 96 | `ios/v1.0.2` | 2026-08-27 | Keep screen awake during voice recording |
| 1.0.1 | 95 | `ios/v1.0.1` | 2026-08-27 | Discard deploy workspace changes before release rebase |
| 1.0.0 | — | `ios/v1.0.0` | 2026-08-26 | SemVer baseline; prior TF builds used marketing `1.0` |
