import Foundation

@main
struct ActivityArbiterTests {
    static func main() throws {
        try automaticSelectionPrefersNewestWorkingSession()
        try waitingStatusOutranksWorkingStatus()
        try fixedSelectionScopesToOneProvider()
        try eventKindsSupplySafeActivityDefaults()
        try staleEventsCannotOverwriteCurrentStatus()
        try percentagesAreNormalized()
        try clearingAStatusRemovesItFromSelection()
        print("ActivityArbiterTests: PASS")
    }

    private static func automaticSelectionPrefersNewestWorkingSession() throws {
        var arbiter = ActivityArbiter(enabledProviderIDs: [.codex, .claudeCode])
        let start = Date(timeIntervalSince1970: 100)

        let codex = arbiter.ingest(event(.codex, "codex-1", .working, at: start))
        try check(codex?.providerID == .codex, "Codex should be selected first")

        let claude = arbiter.ingest(event(.claudeCode, "claude-1", .working, at: start.addingTimeInterval(1)))
        try check(claude?.providerID == .claudeCode, "newest working provider should win")

        let fallback = arbiter.ingest(event(.claudeCode, "claude-1", .idle, at: start.addingTimeInterval(2)))
        try check(fallback?.providerID == .codex, "another working provider should regain priority")

        let stableIdle = arbiter.ingest(event(.codex, "codex-1", .idle, at: start.addingTimeInterval(3)))
        try check(stableIdle?.providerID == .codex, "the last active session should remain selected when idle")
    }

    private static func fixedSelectionScopesToOneProvider() throws {
        var arbiter = ActivityArbiter(
            enabledProviderIDs: [.codex, .claudeCode],
            selection: .fixed(.claudeCode)
        )
        let start = Date(timeIntervalSince1970: 200)

        let codexOnly = arbiter.ingest(event(.codex, "codex-1", .working, at: start))
        try check(codexOnly == nil, "fixed selection should not leak another provider")

        let claude = arbiter.ingest(event(.claudeCode, "claude-1", .idle, at: start.addingTimeInterval(1)))
        try check(claude?.providerID == .claudeCode, "fixed provider should be selected once available")

        let disabled = arbiter.setEnabledProviderIDs([.codex])
        try check(disabled == nil, "a disabled fixed provider should have no status")
    }

    private static func waitingStatusOutranksWorkingStatus() throws {
        var arbiter = ActivityArbiter(enabledProviderIDs: [.codex, .claudeCode])
        let start = Date(timeIntervalSince1970: 150)

        _ = arbiter.ingest(event(.codex, "codex-1", .working, at: start))
        let waiting = arbiter.ingest(
            event(.claudeCode, "claude-1", .waiting, at: start.addingTimeInterval(1))
        )

        try check(waiting?.providerID == .claudeCode, "waiting provider should outrank a working provider")
        try check(waiting?.activity == .waiting, "waiting activity should be preserved")
    }

    private static func eventKindsSupplySafeActivityDefaults() throws {
        var arbiter = ActivityArbiter(enabledProviderIDs: [.geminiCLI])
        let start = Date(timeIntervalSince1970: 300)

        let started = arbiter.ingest(event(.geminiCLI, "gemini-1", nil, kind: .sessionStarted, at: start))
        try check(started?.activity == .working, "session start should default to working")

        let ended = arbiter.ingest(event(.geminiCLI, "gemini-1", nil, kind: .sessionEnded, at: start.addingTimeInterval(1)))
        try check(ended?.activity == .idle, "session end should default to idle")

        let failed = arbiter.ingest(event(.geminiCLI, "gemini-1", nil, kind: .failed, at: start.addingTimeInterval(2)))
        try check(failed?.activity == .error, "failed event should always produce an error")
    }

    private static func staleEventsCannotOverwriteCurrentStatus() throws {
        var arbiter = ActivityArbiter(enabledProviderIDs: [.codex])
        let recent = Date(timeIntervalSince1970: 500)

        _ = arbiter.ingest(event(.codex, "codex-1", .idle, remaining: 60, at: recent))
        let result = arbiter.ingest(event(.codex, "codex-1", .working, remaining: 5, at: recent.addingTimeInterval(-1)))

        try check(result?.activity == .idle, "stale activity should be ignored")
        try check(result?.contextRemainingPercent == 60, "stale usage should be ignored")
    }

    private static func percentagesAreNormalized() throws {
        var arbiter = ActivityArbiter(enabledProviderIDs: [.genericHTTP])
        let quota = AIQuota(
            limitID: "test",
            limitName: "Test quota",
            windows: [
                AIQuotaWindow(id: "primary", windowMinutes: 300, remainingPercent: 130, resetsAt: nil),
                AIQuotaWindow(id: "secondary", windowMinutes: 10_080, remainingPercent: -10, resetsAt: nil)
            ]
        )
        let status = arbiter.ingest(
            event(
                .genericHTTP,
                "http-1",
                .idle,
                remaining: 130,
                quota: quota,
                at: Date(timeIntervalSince1970: 600)
            )
        )

        try check(status?.contextRemainingPercent == 100, "context percentage should be capped at 100")
        try check(status?.quota?.window(id: "primary")?.remainingPercent == 100, "quota should be capped at 100")
        try check(status?.quota?.window(id: "secondary")?.remainingPercent == 0, "quota should be floored at 0")
    }

    private static func clearingAStatusRemovesItFromSelection() throws {
        var arbiter = ActivityArbiter(enabledProviderIDs: [.codex, .claudeCode])
        let start = Date(timeIntervalSince1970: 700)
        _ = arbiter.ingest(event(.codex, "codex-1", .working, at: start))
        _ = arbiter.ingest(event(.claudeCode, "claude-1", .idle, at: start.addingTimeInterval(1)))

        let result = arbiter.ingest(
            event(.codex, "codex-1", nil, kind: .statusCleared, at: start.addingTimeInterval(2))
        )

        try check(result?.providerID == .claudeCode, "cleared status should no longer participate in selection")
        try check(result?.activity == .idle, "remaining provider status should be preserved")
    }

    private static func event(
        _ providerID: AIProviderID,
        _ sessionID: String,
        _ activity: AIActivityState?,
        kind: AIEventKind = .snapshot,
        remaining: Int? = nil,
        quota: AIQuota? = nil,
        at timestamp: Date
    ) -> AIEvent {
        AIEvent(
            providerID: providerID,
            sessionID: sessionID,
            kind: kind,
            activity: activity,
            contextRemainingPercent: remaining,
            contextUsedTokens: nil,
            contextWindow: nil,
            quota: quota,
            modelName: nil,
            timestamp: timestamp
        )
    }

    private static func check(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TestFailure(message) }
    }
}

private struct TestFailure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}
