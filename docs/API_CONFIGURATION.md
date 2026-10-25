# API configuration (KB App API)

The app talks to your deployed **KB App API** after the user picks a server at login and signs in. **Do not commit real hosts or tokens.**

## Runtime sources

| Value | Source |
|-------|--------|
| API base URL | Onboarding / Settings → UserDefaults + App Group |
| Session JWT | Login / register → **Keychain** (App Group) |

Optional **Xcode scheme** env (`KBAPP_API_BASE_URL`, `KBAPP_AUTH_TOKEN`) overrides storage for a single Run / UI-test session. **Info.plist bake-in is ignored.**

Without URL + token the app uses **in-memory stubs** (offline demo) until login.

## Local development on Mac

1. Run the app and enter the server URL on the first onboarding screen (same flow as TestFlight).
2. Sign in or register — the JWT is stored in Keychain.

Optional: set `KBAPP_API_BASE_URL` / `KBAPP_AUTH_TOKEN` under **Edit Scheme → Run → Environment Variables** for tooling or UI tests.

### E2E tests (optional)

Uses `KB_E2E_API_BASE_URL` / `KB_E2E_API_TOKEN` — see [testing/E2E.md](testing/E2E.md).

## TestFlight / GitHub Actions

Release builds do **not** embed an API URL or bearer token. CI writes an empty `Config/Secrets.xcconfig` so plist keys resolve to blank; the user chooses the server in the app.

Signing secrets (`MATCH_*`, `ASC_*`, …) are unchanged — see [FASTLANE.md](FASTLANE.md).

### Deploy workflow

1. **Actions → Deploy TestFlight → Run workflow**.
2. Install from TestFlight → enter server URL → sign in / register.

## Private ops notes

Store production URL, server paths, and rotation notes in your **private** knowledge base (not in this git repo).
