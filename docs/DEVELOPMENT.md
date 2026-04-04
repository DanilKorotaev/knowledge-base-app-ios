# Development

## Layout

- `KnowledgeBaseApp/` — Swift sources (App, Configuration, Models, Services, Views, Resources)
- `KnowledgeBaseWidget/` — WidgetKit extension; **`Info.plist` must keep `NSExtension` / `widgetkit-extension`** (simulator install fails otherwise).
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

## CI

- Workflow: `.github/workflows/ci.yml` — Ruby + **`bundle exec fastlane test`**.
- **No XcodeGen on CI:** the `.xcodeproj` is committed. After changing `project.yml`, run `xcodegen generate` locally and commit the project.
- Coverage gate: **`MIN_COVERAGE`** env (default **35%**), enforced in `fastlane/Fastfile` after scan.
- Manual TestFlight: `.github/workflows/deploy-testflight.yml` — see [FASTLANE.md](FASTLANE.md).
