import Foundation

protocol AIProvider: AnyObject {
    var id: AIProviderID { get }
    var displayName: String { get }
    var capabilities: AIProviderCapabilities { get }

    func start(eventSink: @escaping @Sendable (AIEvent) -> Void)
    func stop()
}
final class AIProviderCoordinator: @unchecked Sendable {
    typealias StatusHandler = @Sendable (AIStatusSnapshot?) -> Void

    private let queue = DispatchQueue(label: "local.tc001.bridge.provider-coordinator")
    private let providers: [AIProvider]
    private let onStatus: StatusHandler
    private var arbiter: ActivityArbiter
    private var started = false

    init(
        providers: [AIProvider],
        enabledProviderIDs: Set<AIProviderID>,
        selection: AIProviderSelection = .automatic,
        onStatus: @escaping StatusHandler
    ) {
        self.providers = providers
        self.onStatus = onStatus
        self.arbiter = ActivityArbiter(
            enabledProviderIDs: enabledProviderIDs,
            selection: selection
        )
    }

    func start() {
        queue.async { [weak self] in
            guard let self, !self.started else { return }
            self.started = true
            for provider in self.providers {
                provider.start { [weak self] event in
                    self?.receive(event)
                }
            }
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self, self.started else { return }
            self.started = false
            self.providers.forEach { $0.stop() }
        }
    }

    func setEnabledProviderIDs(_ providerIDs: Set<AIProviderID>) {
        queue.async { [weak self] in
            guard let self else { return }
            let status = self.arbiter.setEnabledProviderIDs(providerIDs)
            self.onStatus(status)
        }
    }

    func setSelection(_ selection: AIProviderSelection) {
        queue.async { [weak self] in
            guard let self else { return }
            let status = self.arbiter.setSelection(selection)
            self.onStatus(status)
        }
    }

    private func receive(_ event: AIEvent) {
        queue.async { [weak self] in
            guard let self, self.started else { return }
            let status = self.arbiter.ingest(event)
            self.onStatus(status)
        }
    }
}
