import Foundation

enum AIProviderID: String, Codable, CaseIterable, Hashable, Sendable {
    case codex
    case claudeCode
    case geminiCLI
    case genericHTTP

    var displayName: String {
        switch self {
        case .codex: return "Codex"
        case .claudeCode: return "Claude Code"
        case .geminiCLI: return "Gemini CLI"
        case .genericHTTP: return "Generic HTTP"
        }
    }

    var displayPrefix: String {
        switch self {
        case .codex: return "CDX"
        case .claudeCode: return "CLD"
        case .geminiCLI: return "GEM"
        case .genericHTTP: return "AI"
        }
    }
}

struct AIProviderCapabilities: OptionSet, Sendable {
    let rawValue: Int

    static let activity = AIProviderCapabilities(rawValue: 1 << 0)
    static let contextUsage = AIProviderCapabilities(rawValue: 1 << 1)
    static let quotaUsage = AIProviderCapabilities(rawValue: 1 << 2)
    static let modelName = AIProviderCapabilities(rawValue: 1 << 3)
}

struct AIQuotaWindow: Equatable, Sendable {
    let id: String
    let windowMinutes: Int?
    let remainingPercent: Int
    let resetsAt: Date?

    init(
        id: String,
        windowMinutes: Int?,
        remainingPercent: Int,
        resetsAt: Date?
    ) {
        self.id = id
        self.windowMinutes = windowMinutes
        self.remainingPercent = min(100, max(0, remainingPercent))
        self.resetsAt = resetsAt
    }
}

struct AIQuota: Equatable, Sendable {
    let limitID: String?
    let limitName: String?
    let windows: [AIQuotaWindow]

    func window(id: String) -> AIQuotaWindow? {
        windows.first { $0.id == id }
    }

    func window(minutes: Int) -> AIQuotaWindow? {
        windows.first { $0.windowMinutes == minutes }
    }
}

enum AIActivityState: String, Codable, CaseIterable, Sendable {
    case idle
    case working
    case waiting
    case error
}

enum AIEventKind: String, Codable, Sendable {
    case snapshot
    case sessionStarted
    case activityChanged
    case usageUpdated
    case sessionEnded
    case failed
    case statusCleared
}

struct AIEvent: Equatable, Sendable {
    let providerID: AIProviderID
    let sessionID: String
    let kind: AIEventKind
    let activity: AIActivityState?
    let contextRemainingPercent: Int?
    let contextUsedTokens: Int?
    let contextWindow: Int?
    let quota: AIQuota?
    let modelName: String?
    let timestamp: Date
}

struct AIStatusSnapshot: Equatable, Sendable {
    let providerID: AIProviderID
    let sessionID: String
    let activity: AIActivityState
    let contextRemainingPercent: Int?
    let contextUsedTokens: Int?
    let contextWindow: Int?
    let quota: AIQuota?
    let modelName: String?
    let updatedAt: Date
}

enum AIProviderSelection: Equatable, Sendable {
    case automatic
    case fixed(AIProviderID)
}
