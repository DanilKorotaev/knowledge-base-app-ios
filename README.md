# Knowledge Base (iOS)

Native SwiftUI client for the personal knowledge base stack: same PostgreSQL sessions and processing pipeline as the Telegram bot, exposed later via **KB App API** (FastAPI). See the knowledge base implementation plan for the full product picture.

**Repository:** [github.com/DanilKorotaev/knowledge-base-app-ios](https://github.com/DanilKorotaev/knowledge-base-app-ios)

## Requirements

- Xcode 16+
- iOS 17+ deployment target
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — regenerate `KnowledgeBaseApp.xcodeproj` from `project.yml` after structural changes
- Ruby **3.3.x** + Bundler — for **Fastlane** (`bundle install`)

## Quick start

1. Clone the repository.
2. Run `xcodegen generate` (or open the committed `.xcodeproj` after it exists).
3. Open `KnowledgeBaseApp.xcodeproj`.
4. Set your **team** in Signing when you have an Apple Developer account; simulator builds work without it.
5. Optional: `bundle install` then `bundle exec fastlane test` — same path as CI (tests + coverage gate).

## Fastlane & TestFlight

- **Tests:** `bundle exec fastlane test` (optional: `SCAN_DEVICE="iPhone 15"`).
- **TestFlight:** `bundle exec fastlane beta` after Match + App Store Connect API key setup.
- Full checklist: [docs/FASTLANE.md](docs/FASTLANE.md).
- Manual CI upload: GitHub Actions workflow **Deploy TestFlight** (`workflow_dispatch`).

## Configuration

- **Runtime:** `KBAPP_API_BASE_URL` and `KBAPP_AUTH_TOKEN` via Xcode scheme **Environment Variables** or **Settings** inside the app (UserDefaults for development; Keychain planned for tokens).
- **Tooling:** see `env.example` for variable names.
- **Never commit** real URLs with embedded credentials, tokens, or API keys.

Details: [docs/SETUP.md](docs/SETUP.md).

## Documentation

| Document | Description |
|----------|-------------|
| [docs/README.md](docs/README.md) | Documentation index |
| [docs/SETUP.md](docs/SETUP.md) | Environment and Xcode setup |
| [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) | Workflow and XcodeGen |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Modules and future backend boundary |
| [docs/CODING_STANDARDS.md](docs/CODING_STANDARDS.md) | Protocol-first + tests |
| [docs/todo.md](docs/todo.md) | Active tasks |
| [docs/completed.md](docs/completed.md) | Completed tasks |
| [docs/FASTLANE.md](docs/FASTLANE.md) | Match, `fastlane test`, TestFlight |

## Related projects

- **HealthSync** — same Apple Developer account and CI/Fastlane playbook when you add TestFlight.
- **Knowledge Base Telegram bot** — shared domain; backend tasks for the iOS API live in Nextcloud (`Документация/Задачи/KB App API — бэкенд для iOS/`) until a dedicated repo exists.

## License

TBD (add `LICENSE` when you choose a license for the public repo).
