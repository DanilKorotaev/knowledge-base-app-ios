# Development

## Layout

- `KnowledgeBaseApp/` — Swift sources (App, Configuration, Models, Services, Views, Resources)
- `SharedIntents/` — **`StartVoiceRecordingIntent`** opens `knowledgebase://record` with **`OpenURLIntent`** (iOS 18+); used by widget buttons and **`KnowledgeBaseAppShortcuts`** (Shortcuts / Siri).
- `KnowledgeBaseWidget/` — WidgetKit extension; **`NSExtension` / `widgetkit-extension`** is declared in `Info.plist` and merged from **`project.yml`** (`info.properties`); simulator install fails without it.
- `KnowledgeBaseWatchApp/` — watchOS companion (`com.coredan.KnowledgeBaseApp.watch`), embedded in the iOS app.
- `SharedWatchConnectivity/` — WCSession metadata keys + `WatchVoiceContext` (iOS + watchOS).
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
- **Relay:** Watch records → `transferFile` → iPhone `WatchVoiceRelayProcessor` → transcribe + `streamVoiceMessage` → preview back on Watch.
- **Offline:** `WatchPendingRecordingStore` on Watch queues clips when iPhone is unreachable.
- **Deep link:** `knowledgebase://record` opens recording (same scheme as iPhone widget).
- **Complication:** follow-up (separate widget extension + optional `com.coredan.KnowledgeBaseApp.watch.widget`).

Match / TestFlight: include `com.coredan.KnowledgeBaseApp.watch` in `fastlane match appstore --app_identifier …`.

## Voice default session

- **Preference:** `DefaultVoiceSessionPreference` in UserDefaults key `kb.voice.default_session` (JSON).
- **Routing:** `VoiceRoutingContext.resolveVoiceTargetSessionId` — open chat → valid default → first session.
- **UI:** session list swipe/context menu **Voice default** + TTL sheet; mic bar shows `🎙 Session · N min`; Settings → Voice routing → clear.
- **Main-screen recording:** when a valid voice default is set, finishing a recording opens that session’s chat and enqueues the clip into the composer (transcription in the message field). Without a default, the post-record review sheet is used (widget / Watch keep the sheet path later).
- **TTL expiry:** checked on foreground (`scenePhase`) and after session list refresh; restores `previousSessionId` when set.
- **Watch:** `WatchVoiceSessionContextSync` pushes `default_session_id` / `expires_at` via `WCSession.updateApplicationContext` when Watch app is paired.

## CI

- Workflow: `.github/workflows/ci.yml` — Ruby + **`bundle exec fastlane test`**.
- **No XcodeGen on CI:** the `.xcodeproj` is committed. After changing `project.yml`, run `xcodegen generate` locally and commit the project.
- Coverage gate: **`MIN_COVERAGE`** env (default **35%**), enforced in `fastlane/Fastfile` after scan.
- Manual TestFlight: `.github/workflows/deploy-testflight.yml` — see [FASTLANE.md](FASTLANE.md).
