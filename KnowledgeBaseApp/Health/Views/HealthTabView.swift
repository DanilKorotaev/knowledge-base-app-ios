import SwiftUI

struct HealthTabView: View {
    @State private var viewModel = HealthSyncViewModel()

    var body: some View {
        List {
            if !viewModel.isHealthDataAvailable {
                Section {
                    Text("health.error.unavailable")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    if let preview = viewModel.todayPreview {
                        TodayPreviewSection(data: preview)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    } else if case .loadingPreview = viewModel.phase {
                        ProgressView("health.loading_preview")
                    } else if viewModel.needsHealthAuthorization {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("health.authorization.prompt")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                            Button("health.request_access") {
                                Task { await viewModel.requestAuthorization() }
                            }
                        }
                    } else {
                        Text("health.sync.no_preview")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("health.section.today")
                }

                Section {
                    syncStatusRows
                    Button {
                        Task { await viewModel.syncNow() }
                    } label: {
                        if case .syncing = viewModel.phase {
                            HStack {
                                ProgressView()
                                Text("health.sync.running")
                            }
                        } else {
                            Text("health.sync.now")
                        }
                    }
                    .disabled(isSyncing)
                } header: {
                    Text("health.section.sync")
                } footer: {
                    if case .syncing = viewModel.phase {
                        Text("health.sync.running")
                    } else if let lastSyncedAt = viewModel.lastSyncedAt {
                        Text(lastSyncedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                }

                if case let .failed(message) = viewModel.phase {
                    Section("health.section.error") {
                        Text(message)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
        }
        .navigationTitle("tab.health")
        .task {
            await viewModel.refresh()
        }
    }

    @ViewBuilder
    private var syncStatusRows: some View {
        if let state = viewModel.remoteSyncState {
            if let backfill = state.dailyBackfillOldestCompleted {
                LabeledContent("health.sync.backfill_cursor", value: backfill)
            }
            if let daily = state.lastDailyExportDate {
                LabeledContent("health.sync.last_daily", value: daily)
            }
        } else {
            Text("health.sync.no_state")
                .foregroundStyle(.secondary)
        }
    }

    private var isSyncing: Bool {
        if case .syncing = viewModel.phase { return true }
        return false
    }
}

#Preview {
    NavigationStack {
        HealthTabView()
    }
}
