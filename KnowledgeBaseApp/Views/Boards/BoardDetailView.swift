import SwiftUI

struct BoardDetailView: View {
    @State private var viewModel: BoardDetailViewModel
    @State private var showMonthPicker = false
    @State private var showRangePicker = false
    @State private var pickerYear = Calendar.current.component(.year, from: Date())
    @State private var pickerMonth = Calendar.current.component(.month, from: Date())
    @State private var rangeStart: Date?
    @State private var rangeEnd: Date?
    @State private var rangeInitialMonth = Date()

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
                            Text(L10n.format("boards.rendered_at_format", formatRenderedAt(renderedAt)))
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
                    monthMenuButton(option)
                }
                Divider()
                Button(L10n.string("boards.period.pick_month")) {
                    seedMonthPicker()
                    showMonthPicker = true
                }
            case .range:
                Divider()
                ForEach(viewModel.recentMonthOptions(), id: \.self) { option in
                    monthMenuButton(option)
                }
                Divider()
                Button(L10n.string("boards.period.pick_range")) {
                    seedRangePicker()
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

    @ViewBuilder
    private func monthMenuButton(_ option: BoardPeriodSelection) -> some View {
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
            BoardDateRangePickerView(
                rangeStart: $rangeStart,
                rangeEnd: $rangeEnd,
                initialMonth: rangeInitialMonth
            )
            .id(rangePickerIdentity)
            .navigationTitle(L10n.string("boards.period.pick_range"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { showRangePicker = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") {
                        guard let start = rangeStart, let end = rangeEnd else { return }
                        showRangePicker = false
                        Task {
                            await viewModel.setPeriod(
                                BoardPeriodSelection.normalizeRange(from: start, to: end)
                            )
                        }
                    }
                    .disabled(rangeStart == nil || rangeEnd == nil)
                }
            }
        }
        .presentationDetents([
            .height(BoardDateRangePickerView.fittedContentHeight + 56 + 34),
        ])
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(.resizes)
    }

    private var rangePickerIdentity: String {
        let start = rangeStart?.timeIntervalSince1970 ?? -1
        let end = rangeEnd?.timeIntervalSince1970 ?? -1
        let month = rangeInitialMonth.timeIntervalSince1970
        return "\(month)-\(start)-\(end)"
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
        let now = Date()
        switch viewModel.period {
        case let .range(from, to):
            rangeStart = from
            rangeEnd = to
            rangeInitialMonth = from
        case let .month(year, month):
            var comps = DateComponents()
            comps.year = year
            comps.month = month
            comps.day = 1
            if let start = cal.date(from: comps),
               let end = cal.date(byAdding: DateComponents(month: 1, day: -1), to: start)
            {
                rangeStart = start
                rangeEnd = end
                rangeInitialMonth = start
            } else {
                rangeStart = nil
                rangeEnd = nil
                rangeInitialMonth = now
            }
        case .all:
            // No preselection — open on the current month with today ring only.
            rangeStart = nil
            rangeEnd = nil
            rangeInitialMonth = now
        }
    }

    private func formatRenderedAt(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let isoFractional = ISO8601DateFormatter()
        isoFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        let date = isoFractional.date(from: trimmed) ?? iso.date(from: trimmed)
        guard let date else { return trimmed }
        let formatter = DateFormatter()
        formatter.locale = AppLanguageStore.shared.resolvedLocale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        BoardDetailView(boardId: DemoBoardsCatalog.demoKPIId, client: StubBoardsAPIClient())
    }
}
