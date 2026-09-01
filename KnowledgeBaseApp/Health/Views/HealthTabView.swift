import SwiftUI

struct HealthTabView: View {
    @State private var viewModel = HealthSyncViewModel()
    @State private var showArchiveShareSheet = false

    var body: some View {
        List {
            if case let .failed(message) = viewModel.phase {
                Section {
                    Text(message)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }

            if !viewModel.isHealthDataAvailable {
                Section {
                    Text("health.error.unavailable")
                        .foregroundStyle(.secondary)
                }
            } else {
                todaySection
                workoutsStatusSection
                dailyStatusSection
                quickSyncSection
                historySection
                archiveSection
            }
        }
        .navigationTitle("tab.health")
        .task {
            await viewModel.refresh()
        }
        .sheet(isPresented: $showArchiveShareSheet, onDismiss: {
            viewModel.clearExportArchive()
        }) {
            if let url = viewModel.exportArchiveURL {
                ShareSheet(items: [url])
            }
        }
        .onChange(of: viewModel.exportArchiveURL) { _, url in
            showArchiveShareSheet = url != nil
        }
    }

    @ViewBuilder
    private var todaySection: some View {
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
    }

    @ViewBuilder
    private var workoutsStatusSection: some View {
        Section {
            LabeledContent("health.workouts.status") {
                Text(viewModel.workoutsAreOnServer ? "health.workouts.status.synced" : "health.workouts.status.pending")
            }
            if let lastSyncedAt = viewModel.lastSyncedAt, viewModel.workoutsAreOnServer {
                LabeledContent("health.workouts.last_sync") {
                    Text(
                        lastSyncedAt.formatted(
                            Date.FormatStyle(date: .abbreviated, time: .shortened)
                                .locale(AppLanguageStore.shared.resolvedLocale)
                        )
                    )
                }
            }
        } header: {
            Text("health.section.workouts")
        } footer: {
            Text("health.workouts.footer")
        }
    }

    @ViewBuilder
    private var dailyStatusSection: some View {
        Section {
            if let state = viewModel.remoteSyncState {
                if let backfill = state.dailyBackfillOldestCompleted {
                    LabeledContent("health.sync.history_through", value: backfill)
                } else {
                    Text("health.daily.status.none")
                        .foregroundStyle(.secondary)
                }
                if let daily = state.lastDailyExportDate {
                    LabeledContent("health.sync.last_daily", value: daily)
                }
                if !viewModel.isHistoricalBackfillComplete,
                   let remaining = viewModel.estimatedHistoricalDaysRemaining {
                    LabeledContent("health.sync.history_remaining", value: remaining, format: .number)
                }
            } else {
                Text("health.sync.no_state")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("health.section.daily")
        } footer: {
            Text("health.daily.footer")
        }
    }

    @ViewBuilder
    private var quickSyncSection: some View {
        Section {
            Button {
                Task { await viewModel.syncRecent() }
            } label: {
                if viewModel.isBusy && viewModel.activeOperation == .recent {
                    HStack {
                        ProgressView()
                        Text("health.sync.running")
                    }
                } else {
                    Text("health.sync.recent")
                }
            }
            .disabled(viewModel.isBusy)
        } header: {
            Text("health.section.quick_sync")
        } footer: {
            if viewModel.isBusy && viewModel.activeOperation == .recent,
               let stageFooter = viewModel.syncStageFooterText(for: viewModel.phase) {
                Text(stageFooter)
            } else {
                Text("health.sync.recent_footer")
            }
        }
    }

    @ViewBuilder
    private var historySection: some View {
        Section {
            DatePicker(
                "health.history.from",
                selection: $viewModel.historyRangeStart,
                in: ...viewModel.historyRangeEnd,
                displayedComponents: .date
            )
            DatePicker(
                "health.history.to",
                selection: $viewModel.historyRangeEnd,
                in: viewModel.historyRangeStart...Date(),
                displayedComponents: .date
            )
            Button {
                viewModel.syncHistoryRange()
            } label: {
                if viewModel.isBusy && viewModel.activeOperation == .history {
                    HStack {
                        ProgressView()
                        Text("health.sync.running")
                    }
                } else {
                    Text("health.history.sync_button")
                }
            }
            .disabled(viewModel.isBusy)
        } header: {
            Text("health.section.history")
        } footer: {
            if viewModel.isBusy && viewModel.activeOperation == .history,
               let stageFooter = viewModel.syncStageFooterText(for: viewModel.phase) {
                Text(stageFooter)
            } else {
                Text("health.history.footer")
            }
        }
    }

    @ViewBuilder
    private var archiveSection: some View {
        Section {
            DatePicker(
                "health.history.from",
                selection: $viewModel.archiveRangeStart,
                in: ...viewModel.archiveRangeEnd,
                displayedComponents: .date
            )
            DatePicker(
                "health.history.to",
                selection: $viewModel.archiveRangeEnd,
                in: viewModel.archiveRangeStart...Date(),
                displayedComponents: .date
            )
            Toggle("health.archive.include_workouts", isOn: $viewModel.archiveIncludesWorkouts)
            Button {
                Task { await viewModel.exportArchive() }
            } label: {
                if viewModel.isBusy && viewModel.activeOperation == .archive {
                    HStack {
                        ProgressView()
                        Text("health.archive.building")
                    }
                } else {
                    Text("health.archive.export_button")
                }
            }
            .disabled(viewModel.isBusy)
        } header: {
            Text("health.section.archive")
        } footer: {
            if viewModel.isBusy && viewModel.activeOperation == .archive,
               let stageFooter = viewModel.syncStageFooterText(for: viewModel.phase) {
                Text(stageFooter)
            } else {
                Text("health.archive.footer")
            }
        }
    }
}

#Preview {
    NavigationStack {
        HealthTabView()
    }
}
