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
- Design work lives in Figma first; app Theme / Asset catalog comes **after** tokens settle.

## Themes: Light + Dark (required)

Product must support **both** appearances from day one of redesign. Primary authoring target is **Dark** (how Danil uses the app); every screen still needs a Light twin.

Figma Starter allows **one mode per variable collection**, so the file uses:

- `Semantic` (Light)
- `Semantic Dark` (Dark)

On Professional, merge into one collection with Light/Dark modes. Until then: bind Light screens to `Semantic`, Dark screens to `Semantic Dark`.

## Figma file

Working file: [KB App](https://www.figma.com/design/yTzrP1UKQYqKddokP1oC7n) (Starter → 3 pages: **Tokens**, **iOS**, **Platforms**).

| Page | Contents |
|------|----------|
| Tokens | Color / spacing / radius + scenario inventory |
| iOS | Simulator reference PNGs (Light + Dark) — temporary; replace with components later |
| Platforms | Android / Web / Mobile web placeholders |

### Scenario inventory (must be covered)

| Scenario | Notes |
|----------|--------|
| Chats | List + thread chrome |
| SUI · summary | `callout` / `metric` / `table` (JSON-driven) |
| SUI · jobs | tip callout + cancel + `chart` (Actions) |
| SUI · navigation | `list_row` + chevron (`open_board` / `open_tab`) |
| SUI · form | checkbox / radio / date / text / submit |
| Calendar range | Board `period_ui=range` → Choose dates sheet |
| Settings + offline cache | Manage offline cache |
| Health sync | **Redesign focus** — permissions, categories, sync progress, zip/archive export (inspire from watch/Health export apps) |

Stub demos for SUI live in `DemoBoardsCatalog` (`demo-kpi`, `demo-nav`, `demo-form`, `demo-active-jobs`).

## Figma + Cursor

1. Chat: `/add-plugin figma` (or Marketplace → Figma).
2. **Cursor Settings → Tools & MCP → Connect** next to Figma.
3. Open the KB App file → select a frame → **Copy link to selection** → paste into Cursor (“implement this in SwiftUI”).

MCP reads layout/components/variables; still **approve** visuals before large code PRs.

## How we capture “how it looks now”

Prefer Simulator screenshots driven by stub UITests (sharp, repeatable):

| Method | Who | Notes |
|--------|-----|--------|
| `DesignScreenshotUITests` + `simctl ui … appearance` | Agent | Light + Dark PNGs → Figma references |
| Smoke UITests (`-UITesting`) | CI | Functional; not the design gallery |
| Real-account screenshots | Human / agent with credentials | Vault-filled boards, Health |

```bash
# Example (local)
xcrun simctl ui <UDID> appearance light
xcodebuild test -scheme KnowledgeBaseApp -destination "id=<UDID>" \
  -only-testing:KnowledgeBaseAppUITests/DesignScreenshotUITests/testCaptureLightScenarios
xcrun simctl ui <UDID> appearance dark
xcodebuild test … -only-testing:…/testCaptureDarkScenarios
```

Reference PNGs are **pictures**, not components. Next phase: tokens → native-like components → rebuild each screen.

## Redesign workflow

1. Keep Light/Dark reference gallery current (stub + optional real data).
2. Lock tokens (accent, surfaces, text, radii, spacing).
3. Componentize Structured UI blocks (callout variants, metric, list_row, form controls, chart).
4. Screen-by-screen: Settings / offline → Chats → Overview/SUI → Actions → **Health sync** → Login.
5. Mirror IA later for Android Material / Web / Mini App.

## Related

- [`ARCHITECTURE.md`](ARCHITECTURE.md)
- Backend Structured UI: `knowledge-base-bot/docs/kb-app-api/structured-ui.md`
