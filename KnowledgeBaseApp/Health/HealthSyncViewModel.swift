import Foundation

@MainActor
@Observable
final class HealthSyncViewModel {
    enum Phase: Equatable {
        case idle
        case loadingPreview
        case syncing(stage: String, uploadedCount: Int)
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var todayPreview: DailyHealthData?
    private(set) var healthDataRelative: String = "HealthData"
    private(set) var lastSyncedAt: Date?
    private(set) var remoteSyncState: SyncState?
    private(set) var isHealthDataAvailable = false
    private(set) var authorizationGranted = false

    private let healthKit: HealthKitServiceProtocol
    private let syncService: KBHealthSyncService
    private let apiClient: HealthAPIClientProtocol

    init(
        healthKit: HealthKitServiceProtocol = HealthKitService(),
        apiClient: HealthAPIClientProtocol? = URLSessionHealthAPIClient()
    ) {
        self.healthKit = healthKit
        let client = apiClient ?? StubHealthAPIClient()
        self.apiClient = client
        self.syncService = KBHealthSyncService(healthKit: healthKit, apiClient: client)
        self.lastSyncedAt = SyncRunStore.lastSuccessfulSyncAt
        self.isHealthDataAvailable = healthKit.isHealthDataAvailable
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
        } catch {
            // Settings/API optional until configured; keep local defaults.
        }

        phase = .loadingPreview
        do {
            todayPreview = try await syncService.loadTodayPreview()
            phase = .idle
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func requestAuthorization() async {
        guard isHealthDataAvailable else { return }
        do {
            try await healthKit.requestReadAuthorization()
            authorizationGranted = true
            await refresh()
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func syncNow() async {
        guard isHealthDataAvailable else {
            phase = .failed(String(localized: "health.error.unavailable"))
            return
        }
        syncService.onProgress = { [weak self] stage, count in
            Task { @MainActor in
                self?.phase = .syncing(stage: stage, uploadedCount: count)
            }
        }
        phase = .syncing(stage: "starting", uploadedCount: 0)
        do {
            try await syncService.syncNow()
            lastSyncedAt = SyncRunStore.lastSuccessfulSyncAt
            remoteSyncState = try await apiClient.fetchSyncState()
            await refresh()
            phase = .idle
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func updateHealthFolder(_ value: String) async {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let settings = try await apiClient.updateSettings(healthDataRelative: trimmed)
            healthDataRelative = settings.healthDataRelative
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
