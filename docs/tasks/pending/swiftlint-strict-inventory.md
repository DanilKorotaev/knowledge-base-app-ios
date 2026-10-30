# SwiftLint strict inventory (2026-10-30)

Generated with `swiftlint lint --config .swiftlint-strict.yml --reporter json`.

- **Total violations (baseline):** 1334
- **Unique rules (baseline):** 40
- **By severity (baseline):** {'Warning': 1306, 'Error': 28}

## Progress notes

- **2026-10-30 iteration 1:** fixed all `trailing_comma` (109 → 0 via `--fix`); rule re-enabled in `.swiftlint.yml` (soft CI). Baseline table below still shows the original snapshot; refresh JSON/summary when closing a larger batch.
- **2026-10-30 iteration 2:** fixed all `sorted_imports` (90 → 0 via `--fix`); rule added to soft `opt_in_rules`.

## By rule (descending)

| Count | Rule |
|------:|------|
| 215 | `required_deinit` |
| 199 | `force_unwrapping` |
| 178 | `line_length` |
| ~~109~~ **0** | `trailing_comma` *(cleared; soft-enabled)* |
| 94 | `non_optional_string_data_conversion` |
| ~~90~~ **0** | `sorted_imports` *(cleared; soft-enabled)* |
| 72 | `identifier_name` |
| 69 | `number_separator` |
| 45 | `attributes` |
| 44 | `trailing_closure` |
| 31 | `file_name` |
| 28 | `pattern_matching_keywords` |
| 27 | `type_body_length` |
| 24 | `function_body_length` |
| 21 | `file_length` |
| 12 | `cyclomatic_complexity` |
| 12 | `file_header` |
| 7 | `vertical_whitespace` |
| 7 | `opening_brace` |
| 6 | `implicit_optional_initialization` |
| 6 | `modifier_order` |
| 4 | `large_tuple` |
| 4 | `static_over_final_class` |
| 3 | `multiline_function_chains` |
| 3 | `redundant_type_annotation` |
| 3 | `optional_data_string_conversion` |
| 2 | `type_name` |
| 2 | `vertical_whitespace_closing_braces` |
| 2 | `trailing_newline` |
| 2 | `legacy_multiple` |
| 2 | `function_parameter_count` |
| 2 | `unneeded_synthesized_initializer` |
| 2 | `multiline_literal_brackets` |
| 1 | `for_where` |
| 1 | `force_cast` |
| 1 | `multiple_closures_with_trailing_closure` |
| 1 | `force_try` |
| 1 | `multiline_arguments` |
| 1 | `vertical_parameter_alignment_on_call` |
| 1 | `empty_string` |

## Top files

| Count | File |
|------:|------|
| 134 | `KnowledgeBaseApp/Services/KnowledgeBaseAPIClient.swift` |
| 70 | `KnowledgeBaseAppTests/KnowledgeBaseAPIClientTests.swift` |
| 30 | `KnowledgeBaseAppTests/BoardsAPIClientTests.swift` |
| 26 | `KnowledgeBaseAppTests/KBMessageTests.swift` |
| 26 | `KnowledgeBaseAppTests/ComposerDraftStoreTests.swift` |
| 25 | `KnowledgeBaseAppTests/KBHealthSyncServiceTests.swift` |
| 23 | `KnowledgeBaseShareExtension/ShareAPIClient.swift` |
| 22 | `KnowledgeBaseAppTests/HealthKitServiceTests.swift` |
| 22 | `KnowledgeBaseAppTests/ChatViewModelVoiceRetryTests.swift` |
| 22 | `KnowledgeBaseAppTests/KBStructuredUITests.swift` |
| 21 | `KnowledgeBaseAppTests/Services/AuthAPIClientHTTPTests.swift` |
| 20 | `KnowledgeBaseAppTests/ChatViewModelTests.swift` |
| 19 | `KnowledgeBaseApp/ViewModels/ChatViewModel.swift` |
| 19 | `KnowledgeBaseApp/Services/ChatAPIClient.swift` |
| 17 | `KnowledgeBaseApp/Health/Services/HealthKitService.swift` |
| 17 | `KnowledgeBaseAppTests/Services/AuthSessionStoreTests.swift` |
| 16 | `KnowledgeBaseApp/Services/DemoBoardsCatalog.swift` |
| 16 | `KnowledgeBaseAppTests/DefaultVoiceSessionTests.swift` |
| 16 | `KnowledgeBaseAppTests/HealthAPIClientTests.swift` |
| 15 | `KnowledgeBaseApp/Views/Chat/MarkdownSegmentParser.swift` |
| 14 | `KnowledgeBaseApp/UserDefaults/UserDefaultsDebugValueCodec.swift` |
| 13 | `KnowledgeBaseApp/Views/Boards/StructuredUIChartDetailView.swift` |
| 13 | `KnowledgeBaseAppTests/WatchVoiceRelayProcessorTests.swift` |
| 12 | `KnowledgeBaseAppTests/PushNotificationTests.swift` |
| 10 | `KnowledgeBaseApp/Models/KBStructuredUI.swift` |
| 10 | `KnowledgeBaseAppTests/Services/AuthAPIClientTests.swift` |
| 10 | `KnowledgeBaseAppTests/Services/AttachmentDiskCacheTests.swift` |
| 9 | `KnowledgeBaseApp/Views/Chat/ChatView.swift` |
| 9 | `KnowledgeBaseAppTests/KBSessionTests.swift` |
| 9 | `KnowledgeBaseAppTests/ChatComposerDraftTests.swift` |
| 9 | `KnowledgeBaseAppTests/HealthUtilitiesTests.swift` |
| 8 | `KnowledgeBaseApp/Views/MainView.swift` |
| 8 | `KnowledgeBaseApp/Views/Chat/StructuredUIBoardNodes.swift` |
| 8 | `KnowledgeBaseApp/Views/Chat/StructuredUIRenderer.swift` |
| 8 | `KnowledgeBaseAppTests/VoiceRecordingPauseTests.swift` |
| 8 | `KnowledgeBaseWatchApp/Services/WatchConnectivityCoordinator.swift` |
| 7 | `KnowledgeBaseApp/Health/Views/HealthTabView.swift` |
| 7 | `KnowledgeBaseApp/Health/Services/KBHealthSyncService.swift` |
| 7 | `KnowledgeBaseApp/Services/InMemoryKBStore.swift` |
| 7 | `KnowledgeBaseApp/Services/WatchVoiceSessionContextSync.swift` |
