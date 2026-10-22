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
- Overview: stub **Demo: summary** row (jobs board hidden from Overview)
- Open demo board → Structured UI metrics / table
- Actions: stub **Active jobs** + Cancel demo job

## Accessibility IDs

Stable ids used by tests: `main.newSession`, `session.row.<id>`, `board.row.<id>`, `board.detail.<id>`, `actions.section.<id>`, `composer.textField`, `composer.send`, …
