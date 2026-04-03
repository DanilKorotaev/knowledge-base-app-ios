# Development

## Layout

- `KnowledgeBaseApp/` — Swift sources (App, Configuration, Models, Services, Views, Resources)
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

```bash
xcodebuild test -scheme KnowledgeBaseApp -destination 'platform=iOS Simulator,name=iPhone 16'
```

## CI

- Workflow: `.github/workflows/ci.yml`.
- **No XcodeGen on CI:** the `.xcodeproj` is committed. After changing `project.yml`, run `xcodegen generate` locally and commit the project.
- Coverage threshold: `MIN_COVERAGE` in the workflow (baseline starts at 25% for the skeleton; raise as the codebase grows).
