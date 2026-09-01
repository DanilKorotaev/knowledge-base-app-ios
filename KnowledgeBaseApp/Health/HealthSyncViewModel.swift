import Foundation
import UIKit

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

    /// Detached from SwiftUI view lifecycle so tab switches don't cancel long backfills.
    private static var historySyncTask: Task<Void, Never>?

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
        let defaultStart = calendar.date(byAdding: .day, value: -30, to: today) ?? today
        self.historyRangeEnd = today
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

    func syncHistoryRange() {
        guard !isBusy else { return }
        Self.historySyncTask?.cancel()
        Self.historySyncTask = Task.detached(priority: .userInitiated) { @MainActor in
            self.activeOperation = .history
            await self.runSync {
                try await self.syncService.syncDailyHistory(
                    from: self.historyRangeStart,
                    to: self.historyRangeEnd
                )
            }
            self.activeOperation = .none
            Self.historySyncTask = nil
        }
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
        var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "HealthSync") {
            if backgroundTaskID != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTaskID)
                backgroundTaskID = .invalid
            }
        }
        defer {
            if backgroundTaskID != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTaskID)
            }
        }
        do {
            try await operation()
            lastSyncedAt = SyncRunStore.lastSuccessfulSyncAt
            remoteSyncState = try await apiClient.fetchSyncState()
            phase = .idle
            await reloadTodayPreviewIfNeeded()
        } catch is CancellationError {
            HealthSyncLogger.historyCancelled()
            phase = .failed(String(localized: "health.sync.cancelled"))
        } catch {
            HealthSyncLogger.historyFailed(error.localizedDescription)
            phase = .failed(Self.userFacingMessage(for: error))
        }
    }

    private func alignHistoryPickersWithRemoteState() {
        // Resume cursor is applied in KBHealthSyncService — do not shrink the user's date pickers.
    }

    private func reloadTodayPreviewIfNeeded() async {
        guard isHealthDataAvailable, !needsHealthAuthorization else { return }
        do {
            todayPreview = try await syncService.loadTodayPreview()
        } catch {
            // Keep existing preview on failure.
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
