# Fastlane

Test and TestFlight automation. Same playbook as the **Apple Health / HealthSync** plan: **Match** (private Git repo for certs) + **App Store Connect API key** (no interactive 2FA on CI).

## Prerequisites

- Ruby **3.3.x** (see `.ruby-version`). Install with [rbenv](https://github.com/rbenv/rbenv) / [mise](https://mise.jdx.dev/) / system Ruby if compatible.
- Bundler: `gem install bundler`
- Xcode + command-line tools

## Install

From the repository root:

```bash
bundle install
```

## Lane: `test`

Runs **scan** on the **KnowledgeBaseApp** scheme, writes results under `fastlane/test_output/`, then enforces **line coverage** (default minimum **35%**, override with `MIN_COVERAGE`).

```bash
bundle exec fastlane test
```

Optional: pick a simulator name available on your Mac (must be an **iPhone** simulator name from `xcodebuild -showdestinations`):

```bash
SCAN_DEVICE="iPhone 15" bundle exec fastlane test
```

On GitHub Actions, `SCAN_DEVICE` is set automatically before Fastlane runs.

## Lane: `beta` (TestFlight)

**Before the first run:**

1. **App Store Connect** — create the app with bundle ID matching `APP_IDENTIFIER` (change from `com.example.KnowledgeBaseApp` in `project.yml` + `Appfile` when you use a real team).
2. **Private Git repo for Match** — empty repo; you will only store encrypted cert material.
3. **App Store Connect API key** — Users and Access → Integrations → App Store Connect API → generate key (download `.p8` once). Note **Issuer ID** and **Key ID**.

**First-time Match (on your Mac, not CI):**

```bash
export MATCH_PASSWORD='strong passphrase for encrypting the cert repo'
export MATCH_GIT_URL='https://github.com/YOU/knowledge-base-app-certificates.git'
export APP_IDENTIFIER='com.yourteam.KnowledgeBaseApp'   # must match Xcode / ASC

# Optional: HTTPS clone with PAT
# export MATCH_GIT_BASIC_AUTHORIZATION=$(echo -n "x-access-token:ghp_xxx" | base64)

bundle exec fastlane match appstore
```

Commit the updated `Matchfile` `git_url` or always pass `MATCH_GIT_URL` via environment.

**Upload a build locally:**

```bash
export ASC_KEY_ID="..."
export ASC_ISSUER_ID="..."
export ASC_KEY_CONTENT="$(cat AuthKey_XXX.p8)"   # raw PEM contents

export MATCH_PASSWORD="..."
export MATCH_GIT_URL="..."
# export MATCH_GIT_BASIC_AUTHORIZATION=...       # if Match repo is private HTTPS

bundle exec fastlane beta
```

On CI, use **GitHub Secrets** (same names as env vars). Manual deploy: **Actions → Deploy TestFlight → Run workflow** (see `.github/workflows/deploy-testflight.yml`).

## GitHub Secrets (reference)

| Secret | Used by |
|--------|---------|
| `MATCH_PASSWORD` | Match decrypt |
| `MATCH_GIT_URL` | Match clone |
| `MATCH_GIT_BASIC_AUTHORIZATION` | Private Match repo over HTTPS (`base64` of `x-access-token:PAT`) |
| `ASC_KEY_ID` | App Store Connect API |
| `ASC_ISSUER_ID` | App Store Connect API |
| `ASC_KEY_CONTENT` | Contents of `.p8` |
| `APP_IDENTIFIER` | Optional override (default in `Appfile`) |
| `TEAM_ID` | Apple Developer Team ID if needed for signing |

## Shared Apple Developer account with HealthSync

You can use **one** Match repo per app or share patterns; bundle IDs differ, so profiles and certs are **per app**. Same **Apple Developer Program** membership is fine for both apps.
