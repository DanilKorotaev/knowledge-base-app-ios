# Knowledge Base (iOS)

Native SwiftUI client for the multi-user **KB App API** (JWT, chats, boards, Actions, push). Backend: `knowledge-base-bot`. Design notes: [docs/UI.md](docs/UI.md).

**Repository:** [github.com/DanilKorotaev/knowledge-base-app-ios](https://github.com/DanilKorotaev/knowledge-base-app-ios)

## Requirements

- Xcode 16+
- iOS 18+ deployment target (App Intents + `OpenURLIntent` for widget / Shortcuts)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — regenerate `KnowledgeBaseApp.xcodeproj` from `project.yml` after structural changes
- Ruby **3.3.x** + Bundler — for **Fastlane** (`bundle install`)

## Quick start

1. Clone the repository.
2. Run `xcodegen generate` (or open the committed `.xcodeproj` after it exists).
3. Open `KnowledgeBaseApp.xcodeproj`.
4. Set your **team** in Signing when you have an Apple Developer account; simulator builds work without it.
5. **Before push to `main`:** `bundle install` then **`bundle exec fastlane test`** — same as CI (tests + **coverage ≥ 35%**). Required for auto TestFlight deploy. Agents: see `.cursor/rules/fastlane-ci-parity.mdc` (no raw `xcodebuild` / standalone deploy scripts for validation).

## Fastlane & TestFlight

- **Versioning:** push to `main` auto-releases (PATCH + changelog + TestFlight). See [docs/RELEASE_PROCESS.md](docs/RELEASE_PROCESS.md).
- **Tests (CI gate):** `bundle exec fastlane test` — must pass with coverage ≥ 35%.
- **TestFlight:** uploaded automatically after green CI on `main`, or manually via Actions → **Deploy TestFlight**.
- Full checklist: [docs/FASTLANE.md](docs/FASTLANE.md).

## Configuration

- **Runtime:** server URL from onboarding / Settings; JWT in Keychain — see [docs/API_CONFIGURATION.md](docs/API_CONFIGURATION.md). No real URLs/tokens in git.
- **Never commit** real URLs with embedded credentials, tokens, or API keys.

Details: [docs/SETUP.md](docs/SETUP.md).

## Documentation

| Document | Description |
|----------|-------------|
| [docs/README.md](docs/README.md) | Documentation index |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Multi-user app architecture |
| [docs/KB_APP_API_CONTRACT.md](docs/KB_APP_API_CONTRACT.md) | HTTP/JSON contract |
| [docs/UI.md](docs/UI.md) | Native UI + Figma workflow |
| [docs/DOCUMENTATION_MAP.md](docs/DOCUMENTATION_MAP.md) | What the Markdown tree is |
| [docs/SETUP.md](docs/SETUP.md) | Environment and Xcode setup |
| [docs/FASTLANE.md](docs/FASTLANE.md) | Match, `fastlane test`, TestFlight |
| [docs/todo.md](docs/todo.md) | Active tasks |

## Related projects

- **knowledge-base-bot** — KB App API backend (`docs/kb-app-api/`).
- **HealthSync** — same Apple Developer / Fastlane playbook.

## License

[MIT](LICENSE)
