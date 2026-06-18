# Coding Standards

Mandatory for all new code in this repository.

## 1) Protocol-first design

- Every service or repository is represented by a protocol.
- Production code depends on abstractions; use constructor injection.
- Avoid singletons for business logic.

Examples:

- `KnowledgeBaseAPIClientProtocol` + `StubKnowledgeBaseAPIClient` / `URLSessionKnowledgeBaseAPIClient`

## 2) Test coverage

- New production behavior should include tests in the same change.
- Prefer unit tests with injected dependencies and URLProtocol-style mocks for HTTP.
- **CI gate:** `KnowledgeBaseApp.app` line coverage must stay **≥ 35%** (`MIN_COVERAGE` in `fastlane/Fastfile` and `.github/workflows/ci.yml`). Below the threshold, CI fails and **TestFlight auto-deploy is skipped**.
- **Before push to `main`:** run `bundle exec fastlane test` locally (same as CI). Do not rely on “tests pass” alone — check the coverage line in the Fastlane output.

## 3) Definition of done

1. Protocol abstraction introduced or updated where applicable.
2. Tests added or updated.
3. Local **`bundle exec fastlane test`** green, including coverage ≥ `MIN_COVERAGE`.
4. Docs or `docs/todo.md` updated if scope or config changed. HTTP surface changes should update **`docs/KB_APP_API_CONTRACT.md`** (and `docs/openapi/kb-app-api.yaml` when applicable) in the same change.

## 4) Project policy

- No secrets, tokens, or personal data in git.
- Externalize configuration (environment variables, Keychain, gitignored local files).
