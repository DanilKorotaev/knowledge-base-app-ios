import SwiftUI

struct BoardDetailView: View {
    @State private var viewModel: BoardDetailViewModel
    @State private var showMonthPicker = false
    @State private var monthPickerDate = Date()

    init(boardId: String, client: BoardsAPIClientProtocol) {
        _viewModel = State(initialValue: BoardDetailViewModel(boardId: boardId, client: client))
    }

    var body: some View {
        Group {
            if viewModel.isLoading, viewModel.detail == nil {
                ProgressView("boards.loading_detail")
            } else if let loadError = viewModel.loadError, viewModel.detail == nil {
                ContentUnavailableView(
                    "boards.could_not_load",
                    systemImage: "exclamationmark.triangle",
                    description: Text(loadError)
                )
            } else if let detail = viewModel.detail {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(viewModel.period.displayLabel())
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let subtitle = detail.board.subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        StructuredUIPanelView(
                            document: detail.document,
                            isSending: false,
                            isInteractive: false,
                            attachmentLoader: nil,
                            onFullscreenImage: nil,
                            onAction: { _, _, _ in }
                        )
                        if let renderedAt = detail.renderedAt ?? detail.board.renderedAt {
                            Text(L10n.format("boards.rendered_at_format", renderedAt))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding()
                }
                .refreshable {
                    await viewModel.refresh()
                }
            } else {
                ContentUnavailableView(
                    "boards.empty_title",
                    systemImage: "square.grid.2x2",
                    description: Text("boards.empty_hint")
                )
            }
        }
        .navigationTitle(viewModel.detail?.board.title ?? "boards.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                periodMenu
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Label("common.refresh", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading || viewModel.isRefreshing)
            }
        }
        .sheet(isPresented: $showMonthPicker) {
            NavigationStack {
                DatePicker(
                    "boards.period.pick_month",
                    selection: $monthPickerDate,
                    displayedComponents: [.yearAndMonth]
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .padding()
                .navigationTitle("boards.period.pick_month")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("common.cancel") { showMonthPicker = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("common.done") {
                            showMonthPicker = false
                            Task {
                                await viewModel.setPeriod(
                                    BoardPeriodSelection.currentMonth(from: monthPickerDate)
                                )
                            }
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .task {
            await viewModel.load()
        }
    }

    private var periodMenu: some View {
        Menu {
            Button {
                Task { await viewModel.setPeriod(.all) }
            } label: {
                if viewModel.period == .all {
                    Label("boards.period.all", systemImage: "checkmark")
                } else {
                    Text("boards.period.all")
                }
            }
            Divider()
            ForEach(viewModel.recentMonthOptions(), id: \.self) { option in
                Button {
                    Task { await viewModel.setPeriod(option) }
                } label: {
                    if viewModel.period == option {
                        Label(option.displayLabel(), systemImage: "checkmark")
                    } else {
                        Text(option.displayLabel())
                    }
                }
            }
            Divider()
            Button("boards.period.pick_month") {
                if case let .month(year, month) = viewModel.period {
                    var comps = DateComponents()
                    comps.year = year
                    comps.month = month
                    comps.day = 1
                    monthPickerDate = Calendar.current.date(from: comps) ?? Date()
                } else {
                    monthPickerDate = Date()
                }
                showMonthPicker = true
            }
        } label: {
            Label("boards.period.menu", systemImage: "calendar")
        }
        .accessibilityLabel(Text("boards.period.menu"))
    }
}

#Preview {
    NavigationStack {
        BoardDetailView(boardId: DemoBoardsCatalog.demoKPIId, client: StubBoardsAPIClient())
    }
}
