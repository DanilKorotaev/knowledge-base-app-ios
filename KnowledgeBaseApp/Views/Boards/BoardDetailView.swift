import SwiftUI

struct BoardDetailView: View {
    @State private var viewModel: BoardDetailViewModel
    @State private var showMonthPicker = false
    @State private var showRangePicker = false
    @State private var rangeSheetDetent: PresentationDetent = .large
    @State private var pickerYear = Calendar.current.component(.year, from: Date())
    @State private var pickerMonth = Calendar.current.component(.month, from: Date())
    @State private var rangeStart = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var rangeEnd = Date()

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
                        if viewModel.periodUi != .none {
                            Text(viewModel.period.displayLabel())
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
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
            if viewModel.periodUi != .none {
                ToolbarItem(placement: .topBarTrailing) {
                    periodMenu
                }
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
            monthPickerSheet
        }
        .sheet(isPresented: $showRangePicker) {
            rangePickerSheet
        }
        .task {
            await viewModel.load()
        }
    }

    @ViewBuilder
    private var periodMenu: some View {
        Menu {
            Button {
                Task { await viewModel.setPeriod(.all) }
            } label: {
                if viewModel.period == .all {
                    Label(L10n.string("boards.period.all"), systemImage: "checkmark")
                } else {
                    Text(L10n.string("boards.period.all"))
                }
            }

            switch viewModel.periodUi {
            case .month:
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
                Button(L10n.string("boards.period.pick_month")) {
                    seedMonthPicker()
                    showMonthPicker = true
                }
            case .range:
                Divider()
                Button(L10n.string("boards.period.pick_range")) {
                    seedRangePicker()
                    rangeSheetDetent = .large
                    showRangePicker = true
                }
            case .none:
                EmptyView()
            }
        } label: {
            Label(L10n.string("boards.period.menu"), systemImage: "calendar")
        }
        .accessibilityLabel(Text(L10n.string("boards.period.menu")))
    }

    private var monthPickerSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Picker("boards.period.month", selection: $pickerMonth) {
                        ForEach(1 ... 12, id: \.self) { month in
                            Text(monthName(month)).tag(month)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)

                    Picker("boards.period.year", selection: $pickerYear) {
                        ForEach(yearOptions, id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal)
            }
            .navigationTitle(L10n.string("boards.period.pick_month"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { showMonthPicker = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") {
                        showMonthPicker = false
                        Task {
                            await viewModel.setPeriod(.month(year: pickerYear, month: pickerMonth))
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var rangePickerSheet: some View {
        NavigationStack {
            BoardDateRangePickerView(rangeStart: $rangeStart, rangeEnd: $rangeEnd)
                .navigationTitle(L10n.string("boards.period.pick_range"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("common.cancel") { showRangePicker = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("common.done") {
                            showRangePicker = false
                            Task {
                                await viewModel.setPeriod(
                                    BoardPeriodSelection.normalizeRange(from: rangeStart, to: rangeEnd)
                                )
                            }
                        }
                    }
                }
        }
        .presentationDetents([.medium, .large], selection: $rangeSheetDetent)
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(.scrolls)
    }

    private var yearOptions: [Int] {
        let current = Calendar.current.component(.year, from: Date())
        return Array((current - 15) ... (current + 1)).reversed()
    }

    private func monthName(_ month: Int) -> String {
        var comps = DateComponents()
        comps.year = 2000
        comps.month = month
        comps.day = 1
        guard let date = Calendar.current.date(from: comps) else { return String(month) }
        let formatter = DateFormatter()
        formatter.locale = AppLanguageStore.shared.resolvedLocale
        formatter.setLocalizedDateFormatFromTemplate("MMMM")
        return formatter.string(from: date)
    }

    private func seedMonthPicker() {
        if case let .month(year, month) = viewModel.period {
            pickerYear = year
            pickerMonth = month
        } else {
            let now = Date()
            pickerYear = Calendar.current.component(.year, from: now)
            pickerMonth = Calendar.current.component(.month, from: now)
        }
    }

    private func seedRangePicker() {
        let cal = Calendar.current
        let from: Date
        let to: Date
        if case let .range(rangeFrom, rangeTo) = viewModel.period {
            from = rangeFrom
            to = rangeTo
        } else if case let .month(year, month) = viewModel.period {
            var comps = DateComponents()
            comps.year = year
            comps.month = month
            comps.day = 1
            if let start = cal.date(from: comps),
               let end = cal.date(byAdding: DateComponents(month: 1, day: -1), to: start)
            {
                from = start
                to = end
            } else {
                to = Date()
                from = cal.date(byAdding: .day, value: -30, to: to) ?? to
            }
        } else {
            to = Date()
            from = cal.date(byAdding: .day, value: -30, to: to) ?? to
        }
        rangeStart = from
        rangeEnd = to
    }
}
#Preview {
    NavigationStack {
        BoardDetailView(boardId: DemoBoardsCatalog.demoKPIId, client: StubBoardsAPIClient())
    }
}
