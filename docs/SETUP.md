# Setup

## Xcode

1. Install Xcode from the Mac App Store.
2. Install XcodeGen (recommended): `brew install xcodegen`
3. From the repo root: `xcodegen generate`
4. Open `KnowledgeBaseApp.xcodeproj`.

## Signing

1. Select the **KnowledgeBaseApp** target → **Signing & Capabilities**.
2. Choose your **Team** when available.
3. Adjust **Bundle Identifier** if needed (default in `project.yml`: `com.example.KnowledgeBaseApp`).

## Configuration and secrets

### Rules

- Do **not** commit hostnames with embedded credentials, API keys, or personal payloads.
- Prefer **Keychain** for bearer tokens before any shared or production use; the skeleton stores the token in UserDefaults only for local development.

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
