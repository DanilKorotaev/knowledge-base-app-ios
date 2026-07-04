# App localization (i18n): String Catalog + language override

**Status:** Backlog  
**Priority:** High  
**Category:** UX / Platform  
**Related:**

- [task-feature-voice-input.md](../completed/task-feature-voice-input.md)
- [task-ux-voice-transcription-retry-without-loss.md](../completed/task-ux-voice-transcription-retry-without-loss.md)
- [task-feature-voice-recording-pause-resume-locked.md](../completed/task-feature-voice-recording-pause-resume-locked.md)

## Problem

The app UI is **mixed English and Russian**. Core navigation (`MainView`, sessions, settings) is mostly English, but several voice/sync/composer flows were added with hard-coded Russian strings. There is no `Localizable.strings` / String Catalog, no locale override in app settings, and no CI check for untranslated keys.

This makes the product feel inconsistent and blocks shipping to non-Russian users without a structured pass.

## Goal

Introduce proper iOS localization:

1. **Default:** follow the device language (`Locale.preferredLanguages`).
2. **Override:** optional app setting (System / English / Russian / …) stored in UserDefaults.
3. **Single source of truth:** String Catalog (`Localizable.xcstrings`) or typed `L10n` wrapper — no user-facing literals in Views/ViewModels.
4. **Coverage:** iOS app, widgets, App Intents, Watch (when applicable).

## Current inventory (user-facing Russian, audit 2026-07-05)

### Voice recording & transcription

| Location | Examples |
|---|---|
| `MicRecordControl.swift` | Fixed to English in pause/resume commit; verify no regressions |
| `PostRecordingReviewSheet.swift` | «Распознаём речь…», «Голосовое не распознано», «Повторить», «Отправить в чат» |
| `ComposerPendingVoiceCaptureView.swift` | «Распознаём речь…», «Голосовое не распознано», «Повторить», «Удалить» |
| `ComposerFileChipView.swift` | fallback «Голосовое» |
| `VoicePipelineErrorMessage.swift` | all transcription/send error strings (RU) |
| `ChatComposerDraft.swift` | unsupported route messages (RU) |
| `KnowledgeBaseAppShortcuts.swift` | Siri phrases (RU) |
| `SharedIntents/StartVoiceRecordingIntent.swift` | title/description (RU) |

### Sync & chat status

| Location | Examples |
|---|---|
| `SyncStatus.swift` | «Обновление…», «Обновлено …», «Офлайн», relative ages («мин назад») |
| `AssistantPendingBubbleView.swift` | «Обработка…», default activity «Обработка ответа» |
| `ChatViewModel.swift` | «Нет подключения к сети» |
| `MainView.swift` | same offline message in `loadError` |

### Widgets & extensions

| Location | Examples |
|---|---|
| `KnowledgeBaseWidget/KnowledgeBaseWidgets.swift` | widget display names/descriptions (RU) |
| `KnowledgeBaseWatchWidget/KnowledgeBaseWatchWidgets.swift` | «Запись», description (RU) |

### Already English (reference baseline)

`MainView` (sessions list, alerts, toolbar), `ChatComposerView` (Photos/Camera/Files/Send), `ChatView` toolbar, most settings/debug screens, pagination loading copy.

### Not user-facing (OK to stay any language)

Unit test fixture strings, comments, docs/tasks, backend SSE fixture labels in tests.

## Scope (v1)

- [ ] Add `Localizable.xcstrings` (Xcode 15+) with **English (base)** + **Russian** translations for all rows in inventory above.
- [ ] Introduce `L10n` helper or `String(localized:)` wrappers; replace hard-coded UI strings in listed files.
- [ ] Migrate `VoicePipelineErrorMessage` to localized keys (errors are user-facing).
- [ ] Migrate `SyncStatus` + relative date formatting via `RelativeDateTimeFormatter` / localized strings.
- [ ] Widgets & App Intents: separate string tables / intent localization bundles.
- [ ] App Settings screen: **Language** picker — `System default` | `English` | `Русский`.
- [ ] Language override applied at app launch (custom `Bundle` token or SwiftUI `environment(\.locale)`).
- [ ] Document convention in `docs/DEVELOPMENT.md`: new UI strings must go through catalog.
- [ ] Add test/lint: grep CI step failing on Cyrillic in `KnowledgeBaseApp/**` Views (except previews) once migration done.

## Scope (v2, optional)

- [ ] Plural rules (`stringsdict`) for message counts, duration, file counts.
- [ ] Localized push notification previews (if server sends RU-only text today).
- [ ] watchOS app strings when Watch UI grows beyond relay status.

## Technical notes

- Prefer **String Catalog** over legacy `.strings` for Xcode sync and export to translators.
- For override vs system: store `kb.app.language_override` (`nil` = system). On change, post notification to refresh SwiftUI roots.
- `RelativeDateTimeFormatter` with explicit `locale` from resolved app locale replaces hand-rolled «мин назад» in `SyncStatusFormatting`.
- Backend/API error messages may remain server language; client wraps known codes with localized fallbacks (already partially done in `VoicePipelineErrorMessage`).

## Acceptance

- [ ] Device set to English → entire main UX in English (no Russian leaks in inventory list).
- [ ] Device set to Russian → same screens in Russian.
- [ ] App override «English» on Russian device → English UI.
- [ ] Widgets and Siri shortcut titles follow same locale resolution rules.
- [ ] No regressions in voice retry, composer draft, locked pause/resume flows.

## Out of scope

- Translating chat message content or assistant replies (server-generated).
- Localizing `knowledge-base-bot` Telegram strings.
- RTL layout audit (future).
