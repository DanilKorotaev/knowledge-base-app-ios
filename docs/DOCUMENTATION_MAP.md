# What are all these Markdown files?

~**95** `*.md` in the iOS repo (not “one giant manual”). Breakdown:

| Count (approx.) | Where | Meaning |
|-----------------|--------|---------|
| **~12** | `docs/*.md` | **Product / ops guides** — ARCHITECTURE, CONTRACT, Fastlane, SETUP, UI, … |
| **~2** | `docs/testing/` | E2E / UI test notes |
| **~50** | `docs/tasks/completed/` (+ `done/`) | **Finished task specs** — historical checklists; keep for archaeology |
| **~15–25** | `docs/tasks/pending/` | **Still open** work (bugs, polish, Watch acceptance, …) |
| **~2** | repo root | `README`, `CHANGELOG` |
| **1** | `fastlane/` | Fastlane README |

So most of the “90 files” are **task tickets in Markdown**, not user-facing docs. Guides to read day-to-day:

- [`README.md`](README.md) (docs index)
- [`ARCHITECTURE.md`](ARCHITECTURE.md)
- [`KB_APP_API_CONTRACT.md`](KB_APP_API_CONTRACT.md)
- [`UI.md`](UI.md)
- [`FASTLANE.md`](FASTLANE.md) / [`RELEASE_PROCESS.md`](RELEASE_PROCESS.md)
- [`todo.md`](todo.md) — short live checklist

We **do not** rewrite every completed task file when product shifts; we update guides + move done tickets out of `pending/`.
