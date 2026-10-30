# Epic: SwiftLint cleanup + Swift 6 concurrency warnings

**Статус:** 🟡 in progress (soft CI green; strict backlog + compiler Sendable remain)  
**Категория:** Infra / Code quality  
**Дата старта:** 2026-10-30

## Goal

Keep **soft** SwiftLint green in CI (`.swiftlint.yml`), then iteratively re-enable rules from the **strict** baseline (`.swiftlint-strict.yml`) and clear remaining Swift compiler concurrency warnings.

## Config paths

| Role | Path |
|------|------|
| Soft (CI / agents) | [`.swiftlint.yml`](../../../.swiftlint.yml) |
| Strict (inventory) | [`.swiftlint-strict.yml`](../../../.swiftlint-strict.yml) |
| Inventory (md) | [`swiftlint-strict-inventory.md`](swiftlint-strict-inventory.md) |
| Inventory (json) | [`swiftlint-strict-inventory.json`](swiftlint-strict-inventory.json) |
| CI script | [`scripts/ci/swiftlint.sh`](../../../scripts/ci/swiftlint.sh) |
| Fastlane | `bundle exec fastlane lint` |

**Baseline inventory (2026-10-30):** **1334** violations across **40** rules (see inventory md). Soft config disables remaining backlog rules + `nesting` and keeps opt-ins that already pass.

**Progress:** Iteration 1 `trailing_comma` (−109). Iteration 2 `sorted_imports` (−90). Iteration 3 `number_separator` (−69 → soft-enabled). Iteration 4 `trailing_closure` (~45 → 0; soft-enabled 2026-10-30). Iteration 5 style/low-risk batch (~33 → 0; soft-enabled 2026-10-30): `opening_brace`, `vertical_whitespace`, `trailing_newline`, `implicit_optional_initialization`, `unneeded_synthesized_initializer`, `modifier_order`, `redundant_type_annotation`. Iteration 6 Force/unsafe (2026-10-30): `force_try` + `force_cast` → 0 and soft-enabled; production `force_unwrapping` cleared (~76 → 0). Iteration 7 (2026-10-30): test `force_unwrapping` **123 → 0** (`Data(…).utf8`, `XCTUnwrap` / `#require`, `TimeZone.gmt`); soft-enabled. Next: size/complexity (`line_length` ~178).

## How to re-enable a rule

1. Pick a subtask below (one rule or a small group).
2. Fix violations (prefer `swiftlint --fix` when correctable).
3. Remove the rule from `disabled_rules` in `.swiftlint.yml` (or add to `opt_in_rules` if it was strict-only).
4. Confirm: `bundle exec fastlane lint` → 0 violations.
5. Optionally refresh inventory:  
   `swiftlint lint --config .swiftlint-strict.yml --reporter summary`
6. Check the subtask off here; move epic to `completed/` when soft ≈ strict for the agreed set.

## Subtasks — SwiftLint rule groups

### High-noise style (correctable / mechanical)

- [x] `trailing_comma` (~109 → 0; soft-enabled 2026-10-30)
- [x] `sorted_imports` (~90 → 0; soft-enabled 2026-10-30)
- [x] `number_separator` (~69 → 0; soft-enabled 2026-10-30)
- [x] `trailing_closure` (~45 → 0; soft-enabled 2026-10-30)
- [x] `opening_brace` / `vertical_whitespace` / `trailing_newline` / `implicit_optional_initialization` / `unneeded_synthesized_initializer` / `modifier_order` / `redundant_type_annotation` (~33 → 0; soft-enabled 2026-10-30)

### Force / unsafe

- [x] `force_cast` / `force_try` (1 each → 0; soft-enabled 2026-10-30)
- [x] `force_unwrapping` (production + tests → 0; soft-enabled 2026-10-30)

### Size / complexity thresholds

- [ ] `line_length` (~175; 173 warning / 2 error under strict defaults)
- [ ] `type_body_length` / `file_length` / `function_body_length` / `function_parameter_count` / `cyclomatic_complexity` / `nesting` / `large_tuple`

### Naming / structure

- [ ] `identifier_name` / `type_name` / `file_name` / `file_header`
- [ ] `required_deinit` (~215 — evaluate whether to keep or drop from strict)
- [ ] `attributes` / `pattern_matching_keywords` / `static_over_final_class`

### String / Data

- [ ] `non_optional_string_data_conversion` (~94)
- [ ] `optional_data_string_conversion` / `empty_string`

### Multiline / layout opt-ins

- [ ] `multiline_arguments` / `multiline_function_chains` / `multiline_literal_brackets` / `vertical_parameter_alignment_on_call` / `vertical_whitespace_closing_braces` / `multiple_closures_with_trailing_closure` / `for_where` / `legacy_multiple`

## Subtasks — remaining Swift compiler warnings (Swift 6 path)

From local `xcodebuild` after the 2026-10-30 clear-cut pass (~20 left):

- [ ] **NSLock in async:** `AuthSessionStore`, `BoardsAPIClient` → async-safe locking / actor
- [ ] **HealthStoreAdapter Sendable:** captures in `DailyHealthKitDataProviding`
- [ ] **Stores Sendable + UserDefaults:** `DefaultVoiceSessionStore`, `PinnedSessionsStore`, `SessionKBModeStore`
- [ ] **`PendingVoiceRelay.metadata: [String: Any]`** in `WatchVoiceRelayCoordinator`
- [ ] **`AnyShape.pathBuilder` Sendable** in `RichMessageBubbleView`

## Done in bootstrap pass

- [x] Introduce SwiftLint soft + strict configs
- [x] Capture strict inventory under `docs/tasks/pending/`
- [x] Fastlane `lint` + CI step (`brew install swiftlint` + `bundle exec fastlane lint`)
- [x] Agent/docs rules: lint alongside tests
- [x] Clear-cut compiler fixes (var→let, deprecated APIs, exhaustive workout cases, dead casts/coalescing, route query capture)

## Notes

- TestFlight ASC **500** from run `41036613607` is likely transient server-side; retry deploy later (build itself OK).
- Soft lint must stay green; do not re-enable a rule in `.swiftlint.yml` until that bucket is clean.
