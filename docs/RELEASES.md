# iOS releases

Mapping of marketing SemVer ↔ TestFlight build ↔ git tag.

Rows are written by `scripts/ci/prepare_release.py` during Deploy TestFlight and finalized (build column) after a successful upload.

| Version | Build (CI) | Git tag | Date | Notes |
|---------|------------|---------|------|-------|
| 1.0.3 | 97 | `ios/v1.0.3` | 2026-08-27 | Restore idle timer immediately on voice Send |
| 1.0.2 | 96 | `ios/v1.0.2` | 2026-08-27 | Keep screen awake during voice recording |
| 1.0.1 | 95 | `ios/v1.0.1` | 2026-08-27 | Discard deploy workspace changes before release rebase |
| 1.0.0 | — | `ios/v1.0.0` | 2026-08-26 | SemVer baseline; prior TF builds used marketing `1.0` |
