# UX: Main tab shell (Chats + Settings), remove session-list mic bar

**Status:** In progress (`feature/main-tab-shell-sessions-settings`) — code + tests done; awaiting merge  
**Related (KB notes):** `Документация/Задачи/task-kb-dashboards-platform.md` (этап A, без Overview пока)

## Goal

Minimal shell before Boards / Structured UI:

- [x] `TabView`: **Chats** | **Settings**
- [x] Remove persistent **mic bar** from the session list
- [x] Move Settings out of the session-list toolbar into the tab bar
- [x] `knowledgebase://record` opens the voice-default (or newest) chat instead of “tap mic below”
- [x] Localization keys: `tab.chats`, `tab.settings`
- [x] `bundle exec fastlane test` green (395 tests, coverage OK)
- [ ] Overview / Boards tab — **not in this task** (after Structured UI)

## Notes

- Voice remains in **chat composer** and **Apple Watch**.
- “Voice default” swipe/menu kept for Watch + record deep links.
