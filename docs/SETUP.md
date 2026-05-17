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

Full guide: **[API_CONFIGURATION.md](API_CONFIGURATION.md)**.

### Rules

- Do **not** commit real API hosts, Bearer tokens, or personal `.env` files.
- **Local Mac:** copy `env.example` → `.env`, fill `KBAPP_*`, run `./scripts/sync-secrets-xcconfig.sh`, then build in Xcode.
- **TestFlight / CI:** same variable **names** as GitHub Secrets (`KBAPP_API_BASE_URL`, `KBAPP_AUTH_TOKEN`).
- **Bearer tokens** from in-app **Settings** go to the **Keychain**; scheme env and build-time plist override for debugging.

### Quick local setup

```bash
cp env.example .env
# edit .env — your API base URL and token (private)
./scripts/sync-secrets-xcconfig.sh
xcodegen generate   # if project.yml changed
```

Open Xcode → **Clean Build Folder** → **Run**.

Optional override per session: **Edit Scheme → Run → Environment Variables** (`KBAPP_API_BASE_URL`, `KBAPP_AUTH_TOKEN`).

### Files

| File | Role |
|------|------|
| `.env` | Local secrets (gitignored); source for `sync-secrets-xcconfig.sh` |
| `Config/Secrets.xcconfig` | Build-time API config → Info.plist (gitignored) |
| `Config/Secrets.xcconfig.example` | Placeholder template only |

## Microphone

`NSMicrophoneUsageDescription` is present for the upcoming voice capture flow; recording UI is not implemented yet.
