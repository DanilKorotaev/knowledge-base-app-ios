# Widgets: App Intents (interactive)

**Status:** Pending — home screen + lock widgets ship; **no** App Intents yet.

## Goal

- Shortcuts / Siri phrases and **button intents** on supported widget families (iOS 17+), e.g. start voice flow without only relying on URL scheme.

## Depends on

- Stable deep-link or in-app route for “voice ready” (already: `knowledgebase://record`).

## Acceptance

- [ ] At least one `AppIntent` exposed to the widget bundle (or app target + shared framework if split).
- [ ] Document intent labels in `README` or `docs/DEVELOPMENT.md`.
