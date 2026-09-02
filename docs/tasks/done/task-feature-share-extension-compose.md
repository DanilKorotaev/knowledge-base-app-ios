# Feature: Share Extension → session compose (share *into* the app)

**Status:** Done (MVP) — voice in extension deferred  
**Priority:** High  
**Category:** Product / UX  
**Related:** [`task-infra-share-extension-signing-app-group.md`](../pending/task-infra-share-extension-signing-app-group.md), [`task-infra-app-group-shared-defaults.md`](../pending/task-infra-app-group-shared-defaults.md), [`task-ux-composer-paste-clipboard-attachments.md`](../pending/task-ux-composer-paste-clipboard-attachments.md)

## Goal (shipped)

From any app’s Share sheet → **Knowledge Base** → pick (or create) a session → compose (text + attachments) → **Send** and/or **Add to draft**. Drafts accumulate across multiple share actions and appear in the main app chat composer for that session.

## Implementation notes

- Target: `KnowledgeBaseShareExtension` (`com.coredan.KnowledgeBaseApp.Share`), embedded in main IPA.
- App Group: `group.com.coredan.KnowledgeBaseApp` — `ComposerDraftStore` + pin/KB-mode prefs + API base URL.
- Keychain access group: `$(AppIdentifierPrefix)com.coredan.KnowledgeBaseApp` — Share reuses Settings token.
- Voice in Share UI: **deferred** (tight extension memory/UX); record in main app composer after draft merge.

## Acceptance

- [x] Knowledge Base appears in system Share sheet for text/URL/image/PDF (activation rules)
- [x] User can pick existing session or create one, then Add to draft and/or Send
- [x] Two shares into the same session accumulate in the main chat composer (`ComposerDraftStore.merge`)
- [x] Fastlane Match / CI Manual signing includes Share target
- [x] Voice: deferred with reason above
