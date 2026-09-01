import Foundation

@MainActor
@Observable
final class HealthSyncViewModel {
    enum Phase: Equatable {
        case idle
        case loadingPreview
        case syncing(stage: String, uploadedCount: Int, totalCount: Int? = nil)
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var todayPreview: DailyHealthData?
    private(set) var healthDataRelative: String = "HealthData"
    private(set) var lastSyncedAt: Date?
    private(set) var remoteSyncState: SyncState?
    private(set) var isHealthDataAvailable = false
    private(set) var authorizationGranted = false
    private(set) var needsHealthAuthorization = false
    enum ActiveOperation: Equatable {
        case none
        case recent
        case history
        case archive
    }

    private(set) var activeOperation: ActiveOperation = .none

    var historyRangeStart: Date
    var historyRangeEnd: Date
    var archiveRangeStart: Date
    var archiveRangeEnd: Date
    var archiveIncludesWorkouts = true
    private(set) var exportArchiveURL: URL?

    var isBusy: Bool {
        if case .syncing = phase { return true }
        return false
    }

    private let healthKit: HealthKitServiceProtocol
    private let syncService: KBHealthSyncService
    private let archiveBuilder: HealthDataArchiveBuilder
    private let apiClient: HealthAPIClientProtocol
    private let calendar: Calendar

    init(
        healthKit: HealthKitServiceProtocol = HealthKitService(),
        apiClient: HealthAPIClientProtocol? = URLSessionHealthAPIClient(),
        calendar: Calendar = .current
    ) {
        self.healthKit = healthKit
        self.calendar = calendar
        let client = apiClient ?? StubHealthAPIClient()
        self.apiClient = client
        self.syncService = KBHealthSyncService(healthKit: healthKit, apiClient: client)
        self.archiveBuilder = HealthDataArchiveBuilder(healthKit: healthKit, calendar: calendar)
        self.lastSyncedAt = SyncRunStore.lastSuccessfulSyncAt
        self.isHealthDataAvailable = healthKit.isHealthDataAvailable

        let today = calendar.startOfDay(for: Date())
        let defaultEnd = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let defaultStart = calendar.date(byAdding: .day, value: -30, to: defaultEnd) ?? defaultEnd
        self.historyRangeEnd = defaultEnd
        self.historyRangeStart = defaultStart
        self.archiveRangeEnd = today
        self.archiveRangeStart = calendar.date(
            byAdding: .day,
            value: -KBHealthSyncService.defaultDailyBackfillMaxAgeDays,
            to: today
        ) ?? defaultStart
    }

    func refresh() async {
        isHealthDataAvailable = healthKit.isHealthDataAvailable
        guard isHealthDataAvailable else { return }

        do {
            let settings = try await apiClient.fetchSettings()
            healthDataRelative = settings.healthDataRelative
            remoteSyncState = try await apiClient.fetchSyncState()
            if let remote = remoteSyncState?.lastSyncedAt,
               let parsed = ISO8601DateFormatter().date(from: remote) {
                lastSyncedAt = parsed
            }
            alignHistoryPickersWithRemoteState()
        } catch {
            // Settings/API optional until configured; keep local defaults.
        }

        needsHealthAuthorization = await healthKit.needsReadAuthorization()
        guard !needsHealthAuthorization else {
            todayPreview = nil
            phase = .idle
            return
        }

        phase = .loadingPreview
        do {
            todayPreview = try await syncService.loadTodayPreview()
            phase = .idle
        } catch let error as HealthKitServiceError where error == .authorizationRequired {
            needsHealthAuthorization = true
            todayPreview = nil
            phase = .idle
        } catch {
            phase = .failed(Self.userFacingMessage(for: error))
        }
    }

    func requestAuthorization() async {
        guard isHealthDataAvailable else { return }
        do {
            try await healthKit.requestReadAuthorization()
            authorizationGranted = true
            needsHealthAuthorization = false
            await refresh()
        } catch {
            phase = .failed(Self.userFacingMessage(for: error))
        }
    }

    func syncRecent() async {
        activeOperation = .recent
        await runSync { try await self.syncService.syncRecent() }
        activeOperation = .none
    }

    func syncHistoryRange() async {
        activeOperation = .history
        await runSync { try await self.syncService.syncDailyHistory(from: self.historyRangeStart, to: self.historyRangeEnd) }
        activeOperation = .none
    }

    func exportArchive() async {
        guard isHealthDataAvailable else {
            phase = .failed(String(localized: "health.error.unavailable"))
            return
        }
        if await healthKit.needsReadAuthorization() {
            needsHealthAuthorization = true
            phase = .failed(String(localized: "health.error.authorization_required"))
            return
        }

        exportArchiveURL = nil
        activeOperation = .archive
        phase = .syncing(stage: "archive", uploadedCount: 0, totalCount: nil)
        do {
            let url = try await archiveBuilder.buildArchive(
                dailyFrom: archiveRangeStart,
                dailyTo: archiveRangeEnd,
                includeWorkouts: archiveIncludesWorkouts
            ) { [weak self] stage, count in
                Task { @MainActor in
                    self?.phase = .syncing(stage: stage, uploadedCount: count, totalCount: nil)
                }
            }
            exportArchiveURL = url
            phase = .idle
            activeOperation = .none
        } catch HealthDataArchiveBuilderError.emptyArchive {
            phase = .failed(String(localized: "health.archive.empty"))
            activeOperation = .none
        } catch {
            phase = .failed(Self.userFacingMessage(for: error))
            activeOperation = .none
        }
    }

    func clearExportArchive() {
        exportArchiveURL = nil
    }

    func updateHealthFolder(_ value: String) async {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let settings = try await apiClient.updateSettings(healthDataRelative: trimmed)
            healthDataRelative = settings.healthDataRelative
        } catch {
            phase = .failed(Self.userFacingMessage(for: error))
        }
    }

    private func runSync(_ operation: () async throws -> Void) async {
        guard isHealthDataAvailable else {
            phase = .failed(String(localized: "health.error.unavailable"))
            return
        }
        if await healthKit.needsReadAuthorization() {
            needsHealthAuthorization = true
            phase = .failed(String(localized: "health.error.authorization_required"))
            return
        }
        syncService.onProgress = { [weak self] stage, count, total in
            Task { @MainActor in
                self?.phase = .syncing(stage: stage, uploadedCount: count, totalCount: total)
            }
        }
        phase = .syncing(stage: "starting", uploadedCount: 0, totalCount: nil)
        do {
            try await operation()
            lastSyncedAt = SyncRunStore.lastSuccessfulSyncAt
            remoteSyncState = try await apiClient.fetchSyncState()
            alignHistoryPickersWithRemoteState()
            await refresh()
            phase = .idle
        } catch {
            phase = .failed(Self.userFacingMessage(for: error))
        }
    }

    private func alignHistoryPickersWithRemoteState() {
        guard let oldestKey = remoteSyncState?.dailyBackfillOldestCompleted,
              let oldestDay = CalendarDayFormatter.startOfDay(fromYyyyMMdd: oldestKey, calendar: calendar),
              let dayBefore = calendar.date(byAdding: .day, value: -1, to: oldestDay) else {
            return
        }
        historyRangeEnd = min(historyRangeEnd, dayBefore)
        if historyRangeStart > historyRangeEnd {
            historyRangeStart = calendar.date(byAdding: .day, value: -30, to: historyRangeEnd) ?? historyRangeEnd
        }
    }

    private static func userFacingMessage(for error: Error) -> String {
        let description = error.localizedDescription
        if description.localizedCaseInsensitiveContains("healthkit entitlement") {
            return String(localized: "health.error.missing_entitlement")
        }
        if let error = error as? HealthKitServiceError, error == .authorizationRequired {
            return String(localized: "health.error.authorization_required")
        }
        if let error = error as? KBHealthSyncServiceError, error == .healthDataUnavailable {
            return String(localized: "health.error.unavailable")
        }
        if let error = error as? KBHealthSyncServiceError, error == .invalidDateRange {
            return String(localized: "health.error.invalid_date_range")
        }
        return error.localizedDescription
    }
}
