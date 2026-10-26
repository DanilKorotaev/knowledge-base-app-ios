# UI & design (native-like)

## Principle: platform-native, not one skin

Like Telegram: **iOS and Android share product flows**, but each looks and feels **native** to its OS (navigation patterns, lists, typography, system materials).

| | iOS | Android (planned) |
|--|-----|-------------------|
| UI kit | SwiftUI + system controls | Jetpack Compose + Material 3 |
| Nav | `TabView`, `NavigationStack` | NavigationBar / bottom bar |
| Lists | `List` / inset grouped | LazyColumn + M3 list |
| Accent | App tint (not “AI purple”) | Material dynamic / brand seed |

Do **not** force identical pixels across platforms. Share: IA (tabs), copy, icon meaning, board/Structured UI schemas.

## Current state

- Mostly **default SwiftUI** chrome (readable MVP; Settings feels sparse; system blue prominent buttons).
- Structured UI / boards already bring richer layouts from the server.
- No shared token file in-repo yet — introduce via Figma variables → small `Theme` / Asset catalog when redesign starts.

## Figma + Cursor

Official **Figma MCP** in Cursor:

1. Chat: `/add-plugin figma` (or Marketplace → Figma).
2. **Cursor Settings → Tools & MCP → Connect** next to Figma → allow account access.
3. In Figma: create file e.g. `KB App` with pages `iOS`, `Android`, `Tokens`.
4. Select a frame → **Copy link to selection** → paste into Cursor chat (“implement this Settings screen in SwiftUI”).

MCP reads layout/components/variables; you still **approve** visuals before large code PRs.

Remote server URL (manual): `https://mcp.figma.com/mcp` — see [Figma + Cursor setup](https://help.figma.com/hc/en-us/articles/39889260656407).

## How we capture “how it looks now”

Prefer **real device / Simulator screenshots** (data-filled), not wireframes alone:

| Method | Who | Notes |
|--------|-----|--------|
| Simulator + XCUITest / Fastlane `ui_test` | Agent or CI | Stub UI; good for chrome, weak for real boards data |
| Manual Simulator screenshots into chat / Figma | Human | Best for “with my vault” |
| SwiftUI `#Preview` | Dev | Fast; agent cannot “see” Xcode canvas unless you export images |
| Future: snapshot tests | CI | Optional regression |

Agent can **drive Simulator UITests** and attach screenshots when lanes exist; for product redesign, drop 4–6 PNGs of live tabs into the chat or Figma.

## Redesign workflow (recommended)

1. Screenshots of live app (Settings, Chats with threads, Overview, Actions, Login).
2. Figma: tokens + 1–2 reference frames (native iOS).
3. Agree frames in chat (link to selection).
4. Implement SwiftUI against frames (small PRs).
5. Mirror IA later for Android Material.

Priority screens: **Settings / account switch** → Chats list → Overview → Login.

## Related

- [`ARCHITECTURE.md`](ARCHITECTURE.md)
- Backend Structured UI: `knowledge-base-bot/docs/kb-app-api/structured-ui.md`
