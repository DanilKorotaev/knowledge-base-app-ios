## What changed

- 

## Why

- 

## Test plan

- [ ] Added/updated tests for behavior changes
- [ ] Ran local tests: `bundle exec fastlane test` (or `xcodebuild test` with the same scheme)
- [ ] No secrets or personal data added to git

## Version & release

Default shipping path is **push to `main`** (no PR required). Deploy auto-bumps **PATCH**, writes `CHANGELOG.md` from commit subjects, then TestFlight + tag `ios/v*`. See `docs/RELEASE_PROCESS.md`.

Only if this PR is used instead of a direct main push:

- [ ] Clear commit subjects (they become changelog lines)
- [ ] For minor/major: set `VERSION` or add `release-bump: minor|major` in the commit body

## Engineering checklist (required)

- [ ] Protocol-first: new service logic is behind protocols
- [ ] Dependency injection used instead of hard coupling
- [ ] Documentation/tasks updated when scope changed
