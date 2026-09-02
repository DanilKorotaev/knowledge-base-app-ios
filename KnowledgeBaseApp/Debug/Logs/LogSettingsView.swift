import SwiftUI

@MainActor
final class LogSettingsViewModel: ObservableObject {
    private let settings = KBLoggerSettings.shared
    private let quickActions = DebugQuickActionsController.shared
    let filesCapabilityRange = 1 ... 100
    /// Presets for max HTTP body bytes kept in verbose logs when truncation is on.
    let httpBodyLimitChoices: [Int] = [
        1_024,
        4_096,
        16_384,
        65_536,
        262_144,
        1_048_576,
        5 * 1_048_576,
        10 * 1_048_576,
    ]

    @Published var isFileLoggerEnabled: Bool {
        didSet {
            settings.isFileLoggerEnabled = isFileLoggerEnabled
            if isFileLoggerEnabled {
                FileLogger.shared.resetWriter()
            }
        }
    }

    @Published var isDebugLogger: Bool {
        didSet { settings.isDebugLogger = isDebugLogger }
    }

    @Published var isVerboseLog: Bool {
        didSet { settings.isVerboseLog = isVerboseLog }
    }

    @Published var truncateLargeHTTPBodies: Bool {
        didSet { settings.truncateLargeHTTPBodies = truncateLargeHTTPBodies }
    }

    @Published var maxHTTPBodyLogBytes: Int {
        didSet {
            let clamped = min(
                KBLoggerSettings.maxMaxHTTPBodyLogBytes,
                max(KBLoggerSettings.minMaxHTTPBodyLogBytes, maxHTTPBodyLogBytes)
            )
            if clamped != maxHTTPBodyLogBytes {
                maxHTTPBodyLogBytes = clamped
                return
            }
            settings.maxHTTPBodyLogBytes = clamped
        }
    }

    @Published var isShakeToSendLogsEnabled: Bool {
        didSet { quickActions.isShakeToSendLogsEnabled = isShakeToSendLogsEnabled }
    }

    @Published var fileStorageCapability: Int {
        didSet {
            do {
                try LogFilesProvider.shared.setMaxFileToStorage(fileStorageCapability)
            } catch {
                fileStorageCapability = oldValue
            }
        }
    }

    init() {
        isFileLoggerEnabled = settings.isFileLoggerEnabled
        isDebugLogger = settings.isDebugLogger
        isVerboseLog = settings.isVerboseLog
        truncateLargeHTTPBodies = settings.truncateLargeHTTPBodies
        maxHTTPBodyLogBytes = settings.maxHTTPBodyLogBytes
        isShakeToSendLogsEnabled = quickActions.isShakeToSendLogsEnabled
        fileStorageCapability = LogFilesProvider.shared.maxFileToStorage
    }

    func httpBodyLimitLabel(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
    }
}

struct LogSettingsView: View {
    @StateObject private var viewModel = LogSettingsViewModel()

    var body: some View {
        Form {
            Toggle("logs.logging_into_file", isOn: $viewModel.isFileLoggerEnabled)
            Toggle("logs.logging_into_console", isOn: $viewModel.isDebugLogger)
            Toggle("logs.verbose_network", isOn: $viewModel.isVerboseLog)

            Section {
                Toggle("logs.truncate_http_bodies", isOn: $viewModel.truncateLargeHTTPBodies)
                if viewModel.truncateLargeHTTPBodies {
                    Picker(selection: $viewModel.maxHTTPBodyLogBytes) {
                        ForEach(viewModel.httpBodyLimitChoices, id: \.self) { value in
                            Text(viewModel.httpBodyLimitLabel(value)).tag(value)
                        }
                    } label: {
                        Text("logs.http_body_limit")
                    }
                }
            } footer: {
                Text("logs.truncate_http_bodies_footer")
            }

            Toggle("logs.shake_to_send", isOn: $viewModel.isShakeToSendLogsEnabled)

            Text("logs.shake_hint")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker(selection: $viewModel.fileStorageCapability) {
                ForEach(viewModel.filesCapabilityRange, id: \.self) { value in
                    Text("\(value)")
                }
            } label: {
                Text("logs.file_storage_capability")
            }

            NavigationLink("logs.tags") {
                LogTagsView(viewModel: LogTagsViewModel(tagsProvider: KBLoggerTagsProvider.shared))
            }
        }
        .navigationTitle("logs.settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
