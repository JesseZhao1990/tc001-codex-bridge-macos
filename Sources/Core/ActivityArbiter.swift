import Foundation

struct ActivityArbiter {
    private struct SessionKey: Hashable {
        let providerID: AIProviderID
        let sessionID: String
    }

    private var enabledProviderIDs: Set<AIProviderID>
    private var selection: AIProviderSelection
    private var sessions: [SessionKey: AIStatusSnapshot] = [:]
    private var lastSelectedKey: SessionKey?

    init(
        enabledProviderIDs: Set<AIProviderID>,
        selection: AIProviderSelection = .automatic
    ) {
        self.enabledProviderIDs = enabledProviderIDs
        self.selection = selection
    }

    mutating func ingest(_ event: AIEvent) -> AIStatusSnapshot? {
        let key = SessionKey(providerID: event.providerID, sessionID: event.sessionID)
        let previous = sessions[key]
        guard previous == nil || event.timestamp >= previous!.updatedAt else {
            return resolve()
        }

        if event.kind == .statusCleared {
            sessions.removeValue(forKey: key)
            if lastSelectedKey == key {
                lastSelectedKey = nil
            }
            return resolve()
        }

        let activity: AIActivityState
        switch event.kind {
        case .sessionStarted:
            activity = event.activity ?? .working
        case .sessionEnded:
            activity = event.activity ?? .idle
        case .failed:
            activity = .error
        case .snapshot, .activityChanged, .usageUpdated:
            activity = event.activity ?? previous?.activity ?? .idle
        case .statusCleared:
            preconditionFailure("statusCleared is handled before status construction")
        }

        sessions[key] = AIStatusSnapshot(
            providerID: event.providerID,
            sessionID: event.sessionID,
            activity: activity,
            contextRemainingPercent: normalizedPercent(event.contextRemainingPercent)
                ?? previous?.contextRemainingPercent,
            contextUsedTokens: event.contextUsedTokens ?? previous?.contextUsedTokens,
            contextWindow: event.contextWindow ?? previous?.contextWindow,
            quota: event.quota ?? previous?.quota,
            modelName: event.modelName ?? previous?.modelName,
            updatedAt: event.timestamp
        )

        return resolve()
    }

    mutating func setEnabledProviderIDs(_ providerIDs: Set<AIProviderID>) -> AIStatusSnapshot? {
        enabledProviderIDs = providerIDs
        return resolve()
    }

    mutating func setSelection(_ newSelection: AIProviderSelection) -> AIStatusSnapshot? {
        selection = newSelection
        return resolve()
    }

    private mutating func resolve() -> AIStatusSnapshot? {
        let candidates = sessions.filter { enabledProviderIDs.contains($0.key.providerID) }
        guard !candidates.isEmpty else {
            lastSelectedKey = nil
            return nil
        }

        let scoped: [(key: SessionKey, value: AIStatusSnapshot)]
        switch selection {
        case .automatic:
            scoped = candidates.map { ($0.key, $0.value) }
        case let .fixed(providerID):
            scoped = candidates
                .filter { $0.key.providerID == providerID }
                .map { ($0.key, $0.value) }
        }
        guard !scoped.isEmpty else { return nil }

        if let waiting = newest(in: scoped.filter { $0.value.activity == .waiting }) {
            lastSelectedKey = waiting.key
            return waiting.value
        }

        if let working = newest(in: scoped.filter { $0.value.activity == .working }) {
            lastSelectedKey = working.key
            return working.value
        }

        if let error = newest(in: scoped.filter { $0.value.activity == .error }) {
            lastSelectedKey = error.key
            return error.value
        }

        if let lastSelectedKey,
           let previous = scoped.first(where: { $0.key == lastSelectedKey }) {
            return previous.value
        }

        guard let newest = newest(in: scoped) else { return nil }
        lastSelectedKey = newest.key
        return newest.value
    }

    private func newest(
        in candidates: [(key: SessionKey, value: AIStatusSnapshot)]
    ) -> (key: SessionKey, value: AIStatusSnapshot)? {
        candidates.max { lhs, rhs in
            if lhs.value.updatedAt != rhs.value.updatedAt {
                return lhs.value.updatedAt < rhs.value.updatedAt
            }
            if lhs.key.providerID.rawValue != rhs.key.providerID.rawValue {
                return lhs.key.providerID.rawValue < rhs.key.providerID.rawValue
            }
            return lhs.key.sessionID < rhs.key.sessionID
        }
    }

    private func normalizedPercent(_ value: Int?) -> Int? {
        value.map { min(100, max(0, $0)) }
    }
}
