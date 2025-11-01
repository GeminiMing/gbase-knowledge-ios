import Foundation
import Combine
import Network

public final class NetworkMonitor: ObservableObject {
    public static let shared = NetworkMonitor()

    @Published public private(set) var isConnected: Bool = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitorQueue")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }
}

