# iOS release process (SemVer)

Default flow — **no PR required** (trunk-based):

```text
agent commit on main (good message)
  → CI tests
  → Deploy TestFlight
      → auto PATCH bump (+ CHANGELOG from commits)
      → archive / upload
      → commit VERSION+CHANGELOG+RELEASES [skip ci]
      → tag ios/vX.Y.Z
```

One meaningful push to `main` ≈ one TestFlight SemVer release.

## Version numbers

| Field | Source | Meaning |
|-------|--------|---------|
| Marketing (`X-KB-App-Version`) | Root [`VERSION`](../VERSION) (written by deploy) | SemVer `MAJOR.MINOR.PATCH` |
| Build (`X-KB-App-Build`) | `GITHUB_RUN_NUMBER` in Fastlane `beta` | Monotonic integer; **not** the same as PATCH |

### When to bump

| Change | Bump | How |
|--------|------|-----|
| Ordinary fix / small feature (default) | **PATCH** | Automatic on each successful main→TestFlight deploy |
| Notable feature (e.g. Structured UI) | **MINOR** | Set `VERSION` to `X.Y.0` in the commit, **or** add trailer `release-bump: minor`, **or** Actions → Deploy → bump=`minor` |
| “Finished product” / App Store-ready reset | **MAJOR** | Same: `VERSION` / `release-bump: major` / dispatch `major` |

You do **not** need to edit `VERSION` for routine work — write a clear commit message; deploy turns it into changelog bullets.

### Commit message tips

- Prefer Conventional Commits prefixes when natural: `feat:`, `fix:`, `docs:` (mapped to Added / Fixed / Changed).
- For an intentional minor/major without editing `VERSION`:

  ```text
  feat: ship structured UI MVP

  release-bump: minor
  ```

## Agent / local workflow

1. Implement the change.
2. Run tests: `bundle exec fastlane test`.
3. Commit with a descriptive subject (this becomes the changelog line).
4. Push to `main`.
5. Wait for CI + TestFlight Telegram notify (`version (build)` + CHANGELOG link).

Optional: put draft notes under `## [Unreleased]` in [`CHANGELOG.md`](../CHANGELOG.md); deploy folds them into the cut version.

## Deploy details

1. [`scripts/ci/prepare_release.py`](../scripts/ci/prepare_release.py) runs **before** Fastlane (local working tree only — not pushed yet).
2. Fastlane syncs marketing version from `VERSION`, build from `GITHUB_RUN_NUMBER`.
3. On **success only**: [`scripts/ci/commit_and_tag_release.sh`](../scripts/ci/commit_and_tag_release.sh) commits metadata with `[skip ci]` and pushes tag `ios/v{VERSION}`.
4. Failed upload does **not** advance the git tag / release commit (safe to retry).

## Traceability

Given `1.2.3 (build 104)` from Settings / API logs:

1. [`CHANGELOG.md`](../CHANGELOG.md) section `1.2.3`
2. Git tag `ios/v1.2.3`
3. [`docs/RELEASES.md`](RELEASES.md) row for build mapping
