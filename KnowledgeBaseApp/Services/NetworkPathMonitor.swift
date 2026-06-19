import Foundation
import Network

/// Observes device network reachability for offline sync UX.
@MainActor
@Observable
final class NetworkPathMonitor {
    static let shared = NetworkPathMonitor()

    private(set) var isOnline = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.coredan.kb.network-path")

    private var started = false

    private init() {}

    func start() {
        guard !started else { return }
        started = true
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isOnline = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }

    func stop() {
        monitor.cancel()
    }

    #if DEBUG
    func setOnlineForTesting(_ online: Bool) {
        isOnline = online
    }
    #endif
}
