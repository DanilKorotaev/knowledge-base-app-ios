import SwiftUI

enum LogsMenuScreen: String, CaseIterable, Identifiable {
    case files
    case settings
    case crashlytics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .files: return L10n.string("logs.files")
        case .settings: return L10n.string("logs.settings")
        case .crashlytics: return L10n.string("logs.crashlytics")
        }
    }
}

struct LogsMenuView: View {
    var body: some View {
        List(LogsMenuScreen.allCases) { screen in
            NavigationLink(screen.title) {
                switch screen {
                case .files:
                    LogFilesView()
                case .settings:
                    LogSettingsView()
                case .crashlytics:
                    CrashlyticsDebugView()
                }
            }
        }
        .navigationTitle("logs.title")
        .navigationBarTitleDisplayMode(.inline)
        .hidesTabBarWhenPushed()
    }
}

struct CrashlyticsDebugView: View {
    @State private var note = ""
    @State private var confirmFatal = false
    @State private var didSendNonFatal = false

    var body: some View {
        Form {
            if CrashReporting.isConfigured {
                Section {
                    TextField("logs.crashlytics_note", text: $note)
                } footer: {
                    Text("logs.crashlytics_note_footer")
                }

                Section {
                    Button("logs.crashlytics_nonfatal") {
                        CrashReporting.recordTestNonFatal(note: note)
                        didSendNonFatal = true
                    }
                    if didSendNonFatal {
                        Text("logs.crashlytics_nonfatal_sent")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("logs.crashlytics_nonfatal_footer")
                }

                Section {
                    Button("logs.crashlytics_fatal", role: .destructive) {
                        confirmFatal = true
                    }
                } footer: {
                    Text("logs.crashlytics_fatal_footer")
                }
            } else {
                Text("logs.crashlytics_unconfigured")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("logs.crashlytics")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: note) { _, _ in
            didSendNonFatal = false
        }
        .confirmationDialog(
            "logs.crashlytics_fatal_confirm",
            isPresented: $confirmFatal,
            titleVisibility: .visible
        ) {
            Button("logs.crashlytics_fatal", role: .destructive) {
                CrashReporting.testCrash(note: note)
            }
            Button("common.cancel", role: .cancel) {}
        }
    }
}
