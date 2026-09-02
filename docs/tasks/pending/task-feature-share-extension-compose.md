# Feature: Share Extension → session compose (share *into* the app)

**Status:** Backlog  
**Priority:** High  
**Category:** Product / UX  
**Blocked by:** Apple Developer + Match setup — see [`task-infra-share-extension-signing-app-group.md`](task-infra-share-extension-signing-app-group.md)  
**Related:** [`task-infra-app-group-shared-defaults.md`](task-infra-app-group-shared-defaults.md), [`task-ux-composer-paste-clipboard-attachments.md`](task-ux-composer-paste-clipboard-attachments.md), composer draft store (`ComposerDraftStore`)

## Problem

Finding files via the in-app picker is slower than sharing from Files / Photos / another app. Users already use the system **Share** sheet; Knowledge Base does not appear there, so there is no path to drop text/files into a chat draft (or send) without opening the main app first.

## Goal

From any app’s Share sheet → **Knowledge Base** → pick (or create) a session → compose (text + attachments, optional voice) → **Send** and/or **Add to draft**. Drafts accumulate across multiple share actions and appear in the main app chat composer for that session.

## Confirmed Apple / signing requirements

Yes — this needs infrastructure the user will provision:

| Piece | Needed? | Notes |
|-------|---------|--------|
| Separate Xcode target | **Yes** | `app-extension` Share Extension (e.g. `KnowledgeBaseShareExtension`) |
| Separate bundle ID | **Yes** | e.g. `com.coredan.KnowledgeBaseApp.Share` (embedded in main IPA; **no** new ASC app) |
| App ID + provisioning profiles | **Yes** | Register App ID; Match `appstore` (+ `development` if used) for the new id |
| App Group | **Yes** | Shared container for drafts + copied share payloads (main app drafts today live under Application Support and are **invisible** to extensions) |
| Keychain access group (recommended) | **Yes** for Send from extension | Reuse bearer token / API config without re-login in the extension |
| Microphone entitlement / usage string on extension | **Only if** voice ships in the extension | See research below |

Widgets already exist; NSE is a separate pending target. Share Extension is another embedded extension, same TestFlight app.

## UX flow (MVP)

1. User taps Share → Knowledge Base.
2. Extension UI:
   - Session list (pinned first, same order ideas as main list; searchable if cheap).
   - **Create new session** (same fields as in-app create: title + Use Knowledge Base if applicable) → create via API → then continue with that session.
   - Preview of shared payload (text snippet / file chips / images).
   - Text field (prefilled with shared text/URL when present).
   - Actions:
     - **Add to draft** — merge into `ComposerDraftStore` for that session (append text, append files); dismiss extension; **do not** require main app to be foreground.
     - **Send** — same compose/send pipeline as chat (network); on success clear only what was sent; on failure keep as draft.
3. Later in main app: open that session → composer already shows accumulated draft → user can edit / Send.

Multiple shares into the same session must **merge**, not replace (file A from Files, then image from Photos → both in draft).

## Payload types (MVP)

Accept common share items (research exact `NSExtensionActivationRule` / UTIs in implementation):

- Plain text / URL  
- Images (jpeg/png/heic)  
- PDF / generic files (respect existing composer attachment limits & MIME rules)  
- Multiple items in one share when the host provides them  

Out of scope MVP: arbitrary folder shares, Live Photos as video, huge videos (same limits as composer).

## Voice in Share Extension (research → decision)

| Option | Feasibility | Recommendation |
|--------|-------------|----------------|
| A. Mic record inside Share Extension | Possible (mic usage string on extension; AVAudioSession) but **tight memory/UI height**, background kill risk, harder UX parity with locked recording | **Phase 2 / spike** — do not block MVP |
| B. “Add voice” opens main app composer for that session with draft already filled | Reliable | Good fallback if A is painful |
| C. No voice in share UI; only text/files | Simplest | Acceptable MVP if spike fails |

Spike acceptance: 30–60s hold-to-record or tap-to-record → file in shared container → same pending-voice / transcribe path as main app **or** explicit “not in extension” decision documented in this task.

## Architecture sketch

```text
Share Extension
  → copy NSItemProvider payloads into App Group container
  → list/create sessions (API + shared auth)
  → merge into ComposerDraftStore (App Group base URL)
  → Send: reuse ChatAPIClient / compose send (shared framework or duplicated thin client)
Main app
  → ComposerDraftStore already loads per session on ChatViewModel init
```

**Prerequisite work (same epic):** move `ComposerDraftStore` (+ pending attachment/voice file roots used by drafts) to App Group with migration from old Application Support path (one-time copy on main app launch).

Prefer a small **shared source set** (or local SPM) used by app + extension: draft models, draft store, attachment limits, API client bits — avoid copy-paste.

## Implementation checklist

### Infra (other task)

- [ ] Bundle ID + Match + App Group + Keychain group — [`task-infra-share-extension-signing-app-group.md`](task-infra-share-extension-signing-app-group.md)

### Product

- [ ] XcodeGen target `KnowledgeBaseShareExtension` + `NSExtension` / `com.apple.share-services` + activation rules
- [ ] Share UI: session picker, create session, text field, attachment chips, **Add to draft** / **Send**
- [ ] Merge semantics into existing session drafts
- [ ] Create-session path mirrors main app API
- [ ] Migrate draft storage to App Group; main app still works offline/online as today
- [ ] Fastlane Match + CI include new App ID (document secrets)
- [ ] Unit tests: draft merge, App Group path migration, activation item mapping
- [ ] Manual E2E: Files → share PDF; Safari → share URL; Photos → share image; two consecutive shares → one composer
- [ ] Spike notes: voice in extension yes/no

## Out of scope

- Share **from** Knowledge Base (export) — different feature  
- Clipboard drag/paste into composer — [`task-ux-composer-paste-clipboard-attachments.md`](task-ux-composer-paste-clipboard-attachments.md)  
- Android  

## Open questions (defaults if unanswered)

1. **Send from extension** — assume **yes** (needs Keychain sharing). If only “Add to draft”, Send can be deferred to main app.  
2. **Default session** — assume **no auto-pick**; show list (optional later: remember last share target).  
3. **KB mode on new session from share** — assume same default as in-app new-session sheet.  

## Acceptance

- [ ] Knowledge Base appears in system Share sheet for text/URL/image/PDF (as configured)  
- [ ] User can pick existing session or create one, then Add to draft and/or Send  
- [ ] Two shares into the same session accumulate in the main chat composer  
- [ ] TestFlight build embeds Share Extension; Match signs without manual hacks  
- [ ] Voice: either works in extension or explicitly deferred with documented reason  
