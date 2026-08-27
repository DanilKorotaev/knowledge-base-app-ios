import SwiftUI

@MainActor
final class LogSettingsViewModel: ObservableObject {
    private let settings = KBLoggerSettings.shared
    private let quickActions = DebugQuickActionsController.shared
    let filesCapabilityRange = 1 ... 100

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
        isShakeToSendLogsEnabled = quickActions.isShakeToSendLogsEnabled
        fileStorageCapability = LogFilesProvider.shared.maxFileToStorage
    }
}

struct LogSettingsView: View {
    @StateObject private var viewModel = LogSettingsViewModel()

    var body: some View {
        Form {
            Toggle("logs.logging_into_file", isOn: $viewModel.isFileLoggerEnabled)
            Toggle("logs.logging_into_console", isOn: $viewModel.isDebugLogger)
            Toggle("logs.verbose_network", isOn: $viewModel.isVerboseLog)
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
