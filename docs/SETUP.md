# Setup

## Xcode

1. Install Xcode from the Mac App Store.
2. Install XcodeGen (recommended): `brew install xcodegen`
3. From the repo root: `xcodegen generate`
4. Open `KnowledgeBaseApp.xcodeproj`.

## Ruby & Fastlane

1. Install Ruby **3.3.x** (see `.ruby-version`), e.g. via [rbenv](https://github.com/rbenv/rbenv) or [mise](https://mise.jdx.dev/).
2. `gem install bundler`
3. `bundle install`
4. Run tests like CI: `bundle exec fastlane test`

Signing, Match, and TestFlight: [FASTLANE.md](FASTLANE.md).

## Signing

1. Select the **KnowledgeBaseApp** target → **Signing & Capabilities**.
2. Choose your **Team** when available.
3. Adjust **Bundle Identifier** if needed (default in `project.yml`: `com.example.KnowledgeBaseApp`).

## Configuration and secrets

### Rules

- Do **not** commit hostnames with embedded credentials, API keys, or personal payloads.
- **Bearer tokens:** saved from in-app **Settings** go to the **Keychain**; legacy values in UserDefaults are migrated once on read. Scheme env `KBAPP_AUTH_TOKEN` still overrides for local runs.

### Environment variables (prefix `KBAPP_`)

| Variable | Meaning |
|----------|---------|
| `KBAPP_API_BASE_URL` | HTTPS base URL of the KB App API (no trailing slash), when deployed |
| `KBAPP_AUTH_TOKEN` | Bearer token for development only |

Set them in **Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables**.

### Files

- `env.example` — template for shell tooling.
- `Config/Secrets.xcconfig.example` — optional build-time overrides; copy to `Config/Secrets.xcconfig` (gitignored).

## Microphone

`NSMicrophoneUsageDescription` is present for the upcoming voice capture flow; recording UI is not implemented yet.
