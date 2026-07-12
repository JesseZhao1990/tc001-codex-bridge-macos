import Foundation

final class CodexProvider: AIProvider, @unchecked Sendable {
    let id: AIProviderID = .codex
    let displayName = "Codex"
    let capabilities: AIProviderCapabilities = [.activity, .contextUsage, .quotaUsage, .modelName]

    private let monitor: CodexMonitor
    private let rateLimitsClient: CodexRateLimitsFetching
    private let queue = DispatchQueue(label: "local.tc001.bridge.provider.codex", qos: .utility)
    private let quotaQueue = DispatchQueue(label: "local.tc001.bridge.provider.codex-quota", qos: .utility)
    private var activityTimer: DispatchSourceTimer?
    private var quotaTimer: DispatchSourceTimer?
    private var eventSink: (@Sendable (AIEvent) -> Void)?
    private var lastSnapshot: CodexSnapshot?
    private var lastQuota: AIQuota?
    private var quotaRefreshInFlight = false

    init(
        monitor: CodexMonitor = CodexMonitor(),
        rateLimitsClient: CodexRateLimitsFetching = CodexRateLimitsClient()
    ) {
        self.monitor = monitor
        self.rateLimitsClient = rateLimitsClient
    }

    func start(eventSink: @escaping @Sendable (AIEvent) -> Void) {
        queue.async { [weak self] in
            guard let self, self.activityTimer == nil else { return }
            self.eventSink = eventSink

            let activityTimer = DispatchSource.makeTimerSource(queue: self.queue)
            activityTimer.schedule(deadline: .now(), repeating: 1.5, leeway: .milliseconds(150))
            activityTimer.setEventHandler { [weak self] in
                self?.poll()
            }
            self.activityTimer = activityTimer
            activityTimer.resume()

            let quotaTimer = DispatchSource.makeTimerSource(queue: self.queue)
            quotaTimer.schedule(deadline: .now(), repeating: 60, leeway: .seconds(5))
            quotaTimer.setEventHandler { [weak self] in
                self?.refreshQuota()
            }
            self.quotaTimer = quotaTimer
            quotaTimer.resume()
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            self.activityTimer?.setEventHandler {}
            self.activityTimer?.cancel()
            self.activityTimer = nil
            self.quotaTimer?.setEventHandler {}
            self.quotaTimer?.cancel()
            self.quotaTimer = nil
            self.eventSink = nil
            self.lastSnapshot = nil
            self.lastQuota = nil
            self.quotaRefreshInFlight = false
        }
    }

    private func poll() {
        guard let snapshot = monitor.snapshot() else {
            if let previous = lastSnapshot {
                eventSink?(Self.clearEvent(for: previous))
                lastSnapshot = nil
                if let lastQuota {
                    eventSink?(Self.accountEvent(quota: lastQuota))
                }
            }
            return
        }
        guard snapshot != lastSnapshot else { return }

        if let previous = lastSnapshot, previous.sessionName != snapshot.sessionName {
            eventSink?(Self.clearEvent(for: previous))
        }
        lastSnapshot = snapshot
        eventSink?(Self.event(from: snapshot, quota: lastQuota))
    }

    private func refreshQuota() {
        guard !quotaRefreshInFlight else { return }
        quotaRefreshInFlight = true
        let client = rateLimitsClient

        quotaQueue.async { [weak self] in
            let result = Result { try client.fetch() }
            self?.queue.async { [weak self] in
                guard let self else { return }
                self.quotaRefreshInFlight = false
                guard self.quotaTimer != nil, case let .success(quota) = result else { return }
                guard quota != self.lastQuota else { return }

                self.lastQuota = quota
                if let snapshot = self.lastSnapshot {
                    self.eventSink?(Self.event(from: snapshot, quota: quota, timestamp: Date()))
                } else {
                    self.eventSink?(Self.accountEvent(quota: quota))
                }
            }
        }
    }

    static func event(
        from snapshot: CodexSnapshot,
        quota: AIQuota? = nil,
        timestamp: Date? = nil
    ) -> AIEvent {
        AIEvent(
            providerID: .codex,
            sessionID: snapshot.sessionName,
            kind: .snapshot,
            activity: snapshot.activity,
            contextRemainingPercent: snapshot.contextRemainingPercent,
            contextUsedTokens: snapshot.usedTokens,
            contextWindow: snapshot.contextWindow,
            quota: quota,
            modelName: snapshot.model,
            timestamp: timestamp ?? snapshot.updatedAt
        )
    }

    private static func accountEvent(quota: AIQuota) -> AIEvent {
        AIEvent(
            providerID: .codex,
            sessionID: "codex-account",
            kind: .usageUpdated,
            activity: .idle,
            contextRemainingPercent: nil,
            contextUsedTokens: nil,
            contextWindow: nil,
            quota: quota,
            modelName: nil,
            timestamp: Date()
        )
    }

    private static func clearEvent(for snapshot: CodexSnapshot) -> AIEvent {
        AIEvent(
            providerID: .codex,
            sessionID: snapshot.sessionName,
            kind: .statusCleared,
            activity: nil,
            contextRemainingPercent: nil,
            contextUsedTokens: nil,
            contextWindow: nil,
            quota: nil,
            modelName: nil,
            timestamp: Date()
        )
    }
}
