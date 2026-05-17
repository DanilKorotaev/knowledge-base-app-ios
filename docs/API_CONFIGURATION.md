# API configuration (KB App API)

The app talks to your deployed **KB App API** when a base URL and Bearer token are configured. **Do not commit real hosts or tokens** — only placeholders in this repository.

## Priority (runtime)

For each value, the first non-empty source wins:

1. **Xcode scheme** environment (`KBAPP_API_BASE_URL`, `KBAPP_AUTH_TOKEN`) — overrides for a single Run session
2. **Info.plist** (`KBAppAPIBaseURL`, `KBAppAuthToken`) — baked in at **build** time from `Config/Secrets.xcconfig`
3. **In-app Settings** — base URL in UserDefaults; token in **Keychain**

Without URL + token the app uses **in-memory stubs** (offline demo).

## Local development on Mac

1. Copy templates (both are gitignored when filled):

   ```bash
   cp env.example .env
   cp Config/Secrets.xcconfig.example Config/Secrets.xcconfig
   ```

2. Edit **`.env`** with your real `KBAPP_API_BASE_URL` and `KBAPP_AUTH_TOKEN` (keep `.env` local only).

3. Sync into xcconfig (needed after changing `.env`). The script escapes `https://` because **`.xcconfig` treats `//` as a comment**:

   ```bash
   chmod +x scripts/sync-secrets-xcconfig.sh
   ./scripts/sync-secrets-xcconfig.sh
   ```

   You do **not** need `xcodegen` after syncing secrets — only **Clean Build** in Xcode. `xcodegen` reads `project.yml`, not `Secrets.xcconfig`; secrets never land in `project.pbxproj`.

4. Regenerate the Xcode project if you changed `project.yml`:

   ```bash
   xcodegen generate
   ```

5. **Product → Clean Build Folder**, then **Run** on simulator or device.

Optional: set the same variables under **Edit Scheme → Run → Environment Variables** instead of xcconfig (scheme overrides plist).

### E2E tests (optional)

Uses separate variables `KB_E2E_API_BASE_URL` / `KB_E2E_API_TOKEN` — see [testing/E2E.md](testing/E2E.md). You can point them at the same API as the app.

## TestFlight / GitHub Actions

Release builds do **not** read your Mac’s `.env`. CI generates `Config/Secrets.xcconfig` from **GitHub Secrets** before `fastlane beta`.

### Required GitHub Secrets

| Secret | Description |
|--------|-------------|
| `KBAPP_API_BASE_URL` | HTTPS base URL, no trailing slash |
| `KBAPP_AUTH_TOKEN` | Bearer token for KB App API |

Add in the repository: **Settings → Secrets and variables → Actions → New repository secret**.

Existing signing secrets (`MATCH_*`, `ASC_*`, …) are unchanged — see [FASTLANE.md](FASTLANE.md).

### Deploy workflow

1. Configure secrets above.
2. **Actions → Deploy TestFlight → Run workflow**.
3. Install the build from TestFlight; API URL/token are embedded from secrets (Settings can still override URL/token on device).

**Security note:** tokens in TestFlight IPAs are extractable; treat as an internal distribution secret. Rotate on the server if a build leaks.

## Private ops notes

Store production URL, server paths, and rotation notes in your **private** knowledge base (not in this git repo).
