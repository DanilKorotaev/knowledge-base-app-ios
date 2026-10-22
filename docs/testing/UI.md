# UI tests (XCUITest + stubs)

Target: `KnowledgeBaseAppUITests`. Launch argument **`-UITesting`** forces stub API/chat/boards clients (see `UITestRuntime`), so CI does not need staging or secrets.

## Run

```bash
bundle exec fastlane ui_test
# or
SCAN_DEVICE="iPhone 16" bundle exec fastlane ui_test
```

## Scenarios (smoke)

- Root tabs: Chats / Overview / Actions / Settings
- Open seeded **Demo session** → messages visible
- **New session** → type → send → user bubble + `Stub reply …`

## Accessibility IDs

Stable ids used by tests: `main.newSession`, `session.row.<id>`, `composer.textField`, `composer.send`, …
