# Development

## Layout

- `KnowledgeBaseApp/` — Swift sources (App, Configuration, Models, Services, Views, Resources)
- `SharedIntents/` — **`StartVoiceRecordingIntent`** opens `knowledgebase://record` with **`OpenURLIntent`** (iOS 18+); used by widget buttons and **`KnowledgeBaseAppShortcuts`** (Shortcuts / Siri).
- `KnowledgeBaseWidget/` — WidgetKit extension; **`NSExtension` / `widgetkit-extension`** is declared in `Info.plist` and merged from **`project.yml`** (`info.properties`); simulator install fails without it.
- `KnowledgeBaseWatchApp/` — watchOS companion (`com.coredan.KnowledgeBaseApp.watch`), embedded in the iOS app.
- `SharedWatchConnectivity/` — WCSession metadata keys + `WatchVoiceContext` (iOS + watchOS).
- `SharedLocalization/` — `Localizable.xcstrings` (EN base + RU), `AppLanguageStore`, `L10n` helper.
- `project.yml` — XcodeGen specification
- `Config/` — shared `xcconfig` files for Debug/Release

## Regenerating the Xcode project

After editing `project.yml`:

```bash
xcodegen generate
```

Commit both `project.yml` and `KnowledgeBaseApp.xcodeproj` so clones build without XcodeGen.

## Building from the command line

```bash
xcodebuild -scheme KnowledgeBaseApp -destination 'generic/platform=iOS Simulator' build
```

## Testing

Recommended (matches CI):

```bash
bundle install
bundle exec fastlane test
```

Optional explicit simulator:

```bash
SCAN_DEVICE="iPhone 15" bundle exec fastlane test
```

Raw `xcodebuild test` still works if you prefer.

## Apple Watch companion

- **Target:** `KnowledgeBaseWatchApp` (`com.coredan.KnowledgeBaseApp.watch`), embedded in the iOS app.
- **Sync:** `WatchVoiceSessionContextSync` on iPhone pushes default voice session via `WCSession.updateApplicationContext`.
- **Relay:** Watch records → `transferFile` (+ `sendMessage` wake when reachable) → iPhone `WatchVoiceRelayProcessor` in background → preview back on Watch.
- **Offline:** `WatchPendingRecordingStore` on Watch queues clips when iPhone is unreachable.
- **Deep link:** `knowledgebase://record` opens recording (same scheme as iPhone widget).
- **Complication:** `KnowledgeBaseWatchWidgetExtension` (`com.coredan.KnowledgeBaseApp.watch.widget`) — `accessoryCircular` mic + `widgetURL("knowledgebase://record")`; embedded in Watch app.

Match / TestFlight: include `com.coredan.KnowledgeBaseApp.watch` in `fastlane match appstore --app_identifier …`.

## Voice default session

- **Preference:** `DefaultVoiceSessionPreference` in UserDefaults key `kb.voice.default_session` (JSON).
- **Routing:** `VoiceRoutingContext.resolveVoiceTargetSessionId` — open chat → valid default → first session.
- **UI:** session list swipe/context menu **Voice default** + TTL sheet; mic bar shows `🎙 Session · N min`; Settings → Voice routing → clear.
- **Main-screen recording:** when a valid voice default is set, finishing a recording opens that session’s chat and enqueues the clip into the composer (transcription in the message field). Without a default, the post-record review sheet is used (widget / Watch keep the sheet path later).
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
