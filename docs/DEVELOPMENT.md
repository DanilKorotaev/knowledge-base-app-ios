# Development

## Layout

- `KnowledgeBaseApp/` — Swift sources (App, Configuration, Models, Services, Views, Resources)
- `SharedIntents/` — **`StartVoiceRecordingIntent`** opens `knowledgebase://record` with **`OpenURLIntent`** (iOS 18+); used by widget buttons and **`KnowledgeBaseAppShortcuts`** (Shortcuts / Siri).
- `KnowledgeBaseWidget/` — WidgetKit extension; **`NSExtension` / `widgetkit-extension`** is declared in `Info.plist` and merged from **`project.yml`** (`info.properties`); simulator install fails without it.
- `KnowledgeBaseShareExtension/` — Share Extension (`com.coredan.KnowledgeBaseApp.Share`): system Share sheet → pick/create session → **Add to draft** / **Send**. Drafts live in App Group `group.com.coredan.KnowledgeBaseApp`; API token via shared Keychain access group.
- `SharedAppGroup/` — App Group id, container URL, composer-draft migration helpers (main app + Share).
- `KnowledgeBaseWatchApp/` — watchOS companion (`com.coredan.KnowledgeBaseApp.watch`), embedded in the iOS app.
- `SharedWatchConnectivity/` — WCSession metadata keys + `WatchVoiceContext` (iOS + watchOS).
- `SharedLocalization/` — `Localizable.xcstrings` (EN base + RU), `AppLanguageStore`, `L10n` helper.
- `project.yml` — XcodeGen specification
- `Config/` — shared `xcconfig` files for Debug/Release

## Regenerating the Xcode project

After editing `project.yml` **or adding/removing Swift sources**:

```bash
xcodegen generate
```

Commit both `project.yml` (if changed) and `KnowledgeBaseApp.xcodeproj` so CI sees new files. See `.cursor/rules/xcodegen-sync.mdc`.

After changing root **`VERSION`**, marketing version is synced in **`fastlane beta`** (and locally via the same script the lane calls). Do not treat a standalone script run as a substitute for the lane — see **Fastlane / CI parity** below.

## Building and testing (CI parity)

**Agents and pre-push validation must use Fastlane** — same entry points as GitHub Actions. See `.cursor/rules/fastlane-ci-parity.mdc`.

```bash
bundle install
bundle exec fastlane test    # required before push to main
```

Optional explicit simulator (CI sets `SCAN_DEVICE` automatically):

```bash
SCAN_DEVICE="iPhone 15" bundle exec fastlane test
```

TestFlight path (needs Match + ASC secrets locally, or CI):

```bash
bundle exec fastlane beta
```

`xcodebuild` alone is fine for a quick compile in Xcode, but **not** for deciding whether CI will pass (no coverage gate, different cwd/flags).

## Testing

Same as **Building and testing** above — `bundle exec fastlane test` is the only pre-push gate documented here.

## Main shell (tabs)

- **Tabs:** Chats (session list + chat stack) · Settings (moved from the session-list toolbar).
- **Overview / Boards** tab is intentionally not shipped yet (after Structured UI).
- **No mic bar** on the session list — voice only from the chat composer or Apple Watch.

## Apple Watch companion

- **Target:** `KnowledgeBaseWatchApp` (`com.coredan.KnowledgeBaseApp.watch`), embedded in the iOS app.
- **Sync:** `WatchVoiceSessionContextSync` on iPhone pushes default voice session via `WCSession.updateApplicationContext`.
- **Relay:** Watch records → `transferFile` (+ `sendMessage` wake when reachable) → iPhone `WatchVoiceRelayProcessor` in background → preview back on Watch.
- **Offline:** `WatchPendingRecordingStore` on Watch queues clips when iPhone is unreachable.
- **Deep link:** `knowledgebase://record` opens the voice-default (or newest) chat on iPhone so recording continues in the composer (same scheme as iPhone widget).
- **Complication:** `KnowledgeBaseWatchWidgetExtension` (`com.coredan.KnowledgeBaseApp.watch.widget`) — `accessoryCircular` mic + `widgetURL("knowledgebase://record")`; embedded in Watch app.

Match / TestFlight: include `com.coredan.KnowledgeBaseApp.watch` in `fastlane match appstore --app_identifier …`.

## Voice default session

- **Preference:** `DefaultVoiceSessionPreference` in UserDefaults key `kb.voice.default_session` (JSON).
- **Routing:** `VoiceRoutingContext.resolveVoiceTargetSessionId` — open chat → valid default → first session.
- **UI:** session list swipe/context menu **Voice default** + TTL sheet; Settings → Voice routing → clear. Banner on the list when TTL expires.
- **Deep link / widget:** `knowledgebase://record` switches to Chats and pushes the resolved target session (record in composer).
- **TTL expiry:** checked on foreground (`scenePhase`) and after session list refresh; restores `previousSessionId` when set.
- **Watch:** `WatchVoiceSessionContextSync` pushes `default_session_id` / `expires_at` via `WCSession.updateApplicationContext` when Watch app is paired.

## Localization

- **Catalog:** `SharedLocalization/Localizable.xcstrings` — English (base) + Russian. Linked from the iOS app, widget, and watch widget targets via `project.yml`.
- **Runtime override:** Settings → **Language** (`System default` / English / Russian). Stored in app `UserDefaults` key `kb.app.language_override`. Widgets follow **system locale** until App Group is added (`task-infra-app-group-shared-defaults.md`).
- **Views:** prefer `Text("catalog.key")` (uses `environment(\.locale)`). ViewModels/services: `L10n.string("catalog.key")` or `L10n.format("catalog.key", args…)`.
- **New UI copy:** add EN + RU entries to the catalog — no inline Cyrillic in `Views/` / `ViewModels/` (CI checks with `scripts/ci/check_no_hardcoded_cyrillic.sh`).
- **Siri phrases:** bilingual phrase list in `KnowledgeBaseAppShortcuts.swift` is intentional (allowlisted in the Cyrillic check).

## CI

- **CI** (`.github/workflows/ci.yml`): `bundle exec fastlane test` on every push/PR to `main` — **tests + line coverage gate** (`MIN_COVERAGE`, default **35%** for `KnowledgeBaseApp.app`).
- **TestFlight** (`.github/workflows/deploy-testflight.yml`): runs automatically **only after green CI** on push to `main`; manual **workflow_dispatch** also available — see [FASTLANE.md](FASTLANE.md).

### Pre-push checklist (`main`)

```bash
bundle exec fastlane test
```

All tests must pass and coverage must be **≥ 35%**. Otherwise TestFlight will not run on push.
