# iOS releases

Mapping of marketing SemVer ↔ TestFlight build ↔ git tag.

Rows are written by `scripts/ci/prepare_release.py` during Deploy TestFlight and finalized (build column) after a successful upload.

| Version | Build (CI) | Git tag | Date | Notes |
|---------|------------|---------|------|-------|
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
