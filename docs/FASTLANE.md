# Fastlane

Test and TestFlight automation. Same playbook as the **Apple Health / HealthSync** plan: **Match** (private Git repo for certs) + **App Store Connect API key** (no interactive 2FA on CI).

**Agents / pre-push:** use **`bundle exec fastlane test`** (and `beta` only with secrets) — not raw `xcodebuild` or standalone `scripts/ci/*`. See `.cursor/rules/fastlane-ci-parity.mdc`.

## Prerequisites

- Ruby **3.3.x** (see `.ruby-version`). Install with [rbenv](https://github.com/rbenv/rbenv) / [mise](https://mise.jdx.dev/) / [Homebrew](https://brew.sh/) (`brew install ruby`). **Do not use macOS system Ruby** (`/usr/bin/ruby`, often 2.6): `bundle exec fastlane` would fall through to `/usr/local/bin/fastlane` and Match encryption breaks on modern OpenSSL.
- Bundler **2.x** (the repo lockfile expects **2.5.x**; avoid Bundler 1.x from old system Ruby).
- Xcode + command-line tools

## Install

From the repository root:

```bash
# If `ruby -v` is not 3.3.x, fix PATH first, e.g. Homebrew:
#   export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
bundle install
```

Confirm Fastlane comes from the bundle (path should be under your gem home / `vendor/bundle`, **not** `/usr/local/bin/fastlane`):

```bash
bundle exec which fastlane
```

## Lane: `test`

Runs **scan** on the **KnowledgeBaseApp** scheme, writes results under `fastlane/test_output/`, then enforces **line coverage for the `KnowledgeBaseApp.app` target only** (SPM dependencies such as Alamofire are excluded). Default minimum **35%**, override with `MIN_COVERAGE`.

**This gate blocks CI** and therefore **auto TestFlight** on `main` when coverage is below the threshold (individual tests may still pass).

```bash
bundle exec fastlane test
```

Optional: pick a simulator name available on your Mac (must be an **iPhone** simulator name from `xcodebuild -showdestinations`):

```bash
SCAN_DEVICE="iPhone 15" bundle exec fastlane test
```

On GitHub Actions, `SCAN_DEVICE` is set automatically before Fastlane runs.

## Versioning (SemVer)

Default path: **push to `main`** → CI → Deploy TestFlight → **auto PATCH** + changelog from commits → tag `ios/v*`. No PR required. Full rules: [RELEASE_PROCESS.md](RELEASE_PROCESS.md).

- **Marketing version** is written to [`VERSION`](../VERSION) by `scripts/ci/prepare_release.py` on deploy (then committed after a successful upload).
- **Build number** on CI is `GITHUB_RUN_NUMBER` (`increment_build_number`). Do not encode SemVer into the build field.
- Human-readable history: [`CHANGELOG.md`](../CHANGELOG.md). Build ↔ tag mapping: [`RELEASES.md`](RELEASES.md).
- Intentional **minor/major**: edit `VERSION`, or commit trailer `release-bump: minor|major`, or Actions → Deploy TestFlight → bump input.

After editing `VERSION` locally (rare):

```bash
bash scripts/ci/sync_marketing_version.sh
```

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

On CI, use **GitHub Secrets** (same names as env vars).

**Deploy triggers** (`.github/workflows/deploy-testflight.yml`):

- **Automatic:** after **CI** succeeds on a **push to `main`** (not on pull requests).
- **Manual:** **Actions → Deploy TestFlight → Run workflow** (e.g. retry without waiting for CI, or deploy a specific ref).

## Telegram (CI notifications)

After **CI** (`test`) and **Deploy TestFlight** (`beta`), the workflow sends a message to Telegram if secrets are set.

1. Create a bot via [@BotFather](https://t.me/BotFather), copy the **token**.
2. Get **chat id** (your user id or a group id): e.g. message the bot, then open `https://api.telegram.org/bot<TOKEN>/getUpdates`, or use [@userinfobot](https://t.me/userinfobot).
3. Add repository secrets (see table below).

**Tests message:** branch, event, passed / failed / skipped counts, app line coverage %, link to the workflow run. On failure, lists failed test identifiers from the `.xcresult` bundle (up to 25).

**TestFlight message:** marketing version + build number (from `fastlane/test_output/ci_testflight.json` after upload), bundle id, CHANGELOG / tag links, success or failure. On success, deploy commits `VERSION` + changelog and tags `ios/v{VERSION}` (with `[skip ci]`).

Local dry-run (no network):

```bash
TELEGRAM_NOTIFY_DISABLED=1 python3 scripts/ci/telegram_notify.py tests --outcome success
```

## GitHub Secrets (reference)


| Secret                          | Used by                                                          |
| ------------------------------- | ---------------------------------------------------------------- |
| `KBAPP_API_BASE_URL`            | **TestFlight build** — KB App API HTTPS base (no trailing slash); written to `Config/Secrets.xcconfig` in CI |
| `KBAPP_AUTH_TOKEN`              | **TestFlight build** — Bearer token for the API (same as local `.env`) |
| `MATCH_PASSWORD`                | Match decrypt                                                    |
| `MATCH_GIT_URL`                 | Match clone                                                      |
| `MATCH_GIT_BASIC_AUTHORIZATION` | Private Match repo over HTTPS (`base64` of `x-access-token:PAT`) |
| `ASC_KEY_ID`                    | App Store Connect API                                            |
| `ASC_ISSUER_ID`                 | App Store Connect API                                            |
| `ASC_KEY_CONTENT`               | Contents of `.p8`                                                |
| `APP_IDENTIFIER`                | Optional override (default in `Appfile`)                         |
| `WIDGET_APP_IDENTIFIER`         | Optional; default `com.coredan.KnowledgeBaseApp.Widget` — **lane `beta`** runs Match for app + widget                                     |
| `WATCH_APP_IDENTIFIER`          | Optional; default `com.coredan.KnowledgeBaseApp.watch` — watchOS companion embedded in iOS app                                           |
| `WATCH_WIDGET_APP_IDENTIFIER`   | Optional; default `com.coredan.KnowledgeBaseApp.watch.widget` — watchOS complication (WidgetKit extension)                               |
| `TEAM_ID`                       | Apple Developer Team ID if needed for signing                    |
| `TELEGRAM_BOT_TOKEN`            | **CI / TestFlight** — Telegram Bot API token (from @BotFather)   |
| `TELEGRAM_CHAT_ID`              | **CI / TestFlight** — chat id to receive notifications           |

KB App API values for TestFlight: [API_CONFIGURATION.md](API_CONFIGURATION.md). **Do not** put real URLs or tokens in the repository — only in GitHub Secrets and local `.env`.


## Shared Apple Developer account with HealthSync

You can use **one** Match repo per app or share patterns; bundle IDs differ, so profiles and certs are **per app**. Same **Apple Developer Program** membership is fine for both apps.