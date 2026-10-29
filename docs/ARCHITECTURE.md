# Architecture (Knowledge Base iOS App)

## Product

Native **iOS client** for the multi-user **KB App API** (`knowledge-base-bot/kb_app_api/`):

- JWT login / register / refresh (Keychain)
- Multiple saved accounts + per-account offline cache
- Chats (SSE), voice, attachments, changed files
- Overview (boards) + Actions (presets / active jobs)
- Structured UI in chat and board documents
- Push (APNs), widgets, Watch voice relay

The app speaks **HTTPS only**. It does not run Cursor or touch Postgres/Nextcloud directly.

Telegram bot / Mini App are **not** this client’s primary story (server-side legacy).

## Runtime shape

```text
┌─────────────────────────────────────────┐
│  KnowledgeBaseApp (SwiftUI)             │
│  Tabs: Chats · Overview · Actions · … · Settings │
└─────────────────┬───────────────────────┘
                  │ Bearer JWT (+ refresh)
                  ▼
┌─────────────────────────────────────────┐
│  KB App API                             │
│  auth · sessions · boards · jobs · push │
└─────┬───────────┬───────────┬───────────┘
      │           │           │
      ▼           ▼           ▼
  per-user     Cursor CLI   APNs
  vault/NC     (query jobs)
```

## Auth & accounts

| Piece | Role |
|-------|------|
| `AuthSessionStore` | Active session, switch / add / sign-out; proactive refresh on launch |
| `SavedAccountsStore` | Keychain list of accounts |
| `ServerURLHistoryStore` | Recent API base URLs for login prefill / suggestions |
| `OfflineCacheScope` | Disk cache rooted by API host + `userId` |
| `KBHTTPTransport` | Resolves Bearer from Keychain **per request** (account switch); forces fresh token after refresh |

On `kbAuthSessionDidChange`, Main / Boards / Actions clear in-memory state and refetch.

**Logout on open (historical bug):** access JWT TTL is ~1h; cold start refreshes near-expiry tokens. After a successful `/refresh`, a retry could still send the *old* Bearer (stale Keychain read), hit 401 again, and call `invalidateLocalSession` (“401 after refresh”). Fixed by forcing the new access token on the retry request and only wiping the session on definitive 401/403 from refresh (not on network/5xx).

## Main modules

| Area | Location |
|------|----------|
| Shell / tabs | `Views/MainView.swift` |
| Auth UI | `Views/Auth/` |
| Chat | `Views/Chat/`, `ViewModels/ChatViewModel.swift` |
| Boards / Actions | `Views/Boards/`, `Views/Actions/`, `ViewModels/BoardsViewModel.swift` |
| Networking | `Services/*APIClient.swift`, `Networking/KBHTTPTransport.swift` |
| Offline | `Services/OfflineCacheStore.swift`, `AttachmentDiskCache.swift` |
| Push / Watch / Widgets | dedicated targets + App Intents |

Stubs (`Stub*`) power UI tests (`-UITesting`) without a server.

## Contract

Canonical HTTP/JSON: [`KB_APP_API_CONTRACT.md`](KB_APP_API_CONTRACT.md)  
Backend guides: `knowledge-base-bot/docs/kb-app-api/`  
Keep contract + client models aligned in the **same** change as API shape changes.

## UI / design

Native-like SwiftUI (platform conventions). Shared product patterns with a future Android app, **not** pixel-identical skins. See [`UI.md`](UI.md).

## Constraints

- Protocol-first services; inject dependencies (`CODING_STANDARDS.md`)
- New logic ships with tests; CI gate: `bundle exec fastlane test` (≥ 35% line coverage)
- No baked production secrets in the binary — server URL at login; JWT in Keychain
