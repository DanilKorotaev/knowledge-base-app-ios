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

- Do **not** commit real API hosts or session tokens.
- Enter the server URL in **onboarding** (or Settings). JWT after login is stored in **Keychain**.
- Info.plist bake-in is **ignored**. Optional scheme env (`KBAPP_*`) is for tooling / UI tests only.

### Quick local setup

```bash
xcodegen generate   # if project.yml changed
```

Open Xcode → **Run** → enter server URL → sign in / register.

Optional override per session: **Edit Scheme → Run → Environment Variables** (`KBAPP_API_BASE_URL`, `KBAPP_AUTH_TOKEN`).

### Files

| File | Role |
|------|------|
| `Config/Secrets.xcconfig` | Empty stubs for INFOPLIST_KEY_* (gitignored); not used at runtime |
| `Config/Secrets.xcconfig.example` | Empty template |

## Microphone

`NSMicrophoneUsageDescription` is present for the upcoming voice capture flow; recording UI is not implemented yet.
