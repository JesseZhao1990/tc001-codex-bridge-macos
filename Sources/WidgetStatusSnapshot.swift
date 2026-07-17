import Foundation

enum WidgetConstants {
    static let kind = "io.github.tc001bridge.macos.status-widget"
    static let statusEndpoint = URL(string: "http://127.0.0.1:8765/widget/status")!
    static let appURLScheme = "tc001bridge"
    static let appURL = URL(string: "\(appURLScheme)://status")!
}

enum WidgetQuotaSource: String, Codable, Sendable {
    case codex
    case manual
}

enum WidgetActivityState: String, Codable, Sendable {
    case idle
    case working
    case waiting
    case error
}

enum WidgetConnectionState: String, Codable, Sendable {
    case unknown
    case checking
    case connected
    case failed
}

struct WidgetStatusSnapshot: Codable, Equatable, Sendable {
    let generatedAt: Date
    let quotaSource: WidgetQuotaSource
    let fiveHourRemainingPercent: Int?
    let sevenDayRemainingPercent: Int?
    let manualRemainingPercent: Int?
    let showsFiveHourQuota: Bool
    let showsSevenDayQuota: Bool
    let activity: WidgetActivityState
    let sourceTitle: String
    let transportTitle: String
    let connection: WidgetConnectionState
    let batteryPercent: Int?
    let lastSyncDate: Date?

    init(
        generatedAt: Date,
        quotaSource: WidgetQuotaSource,
        fiveHourRemainingPercent: Int?,
        sevenDayRemainingPercent: Int?,
        manualRemainingPercent: Int?,
        showsFiveHourQuota: Bool,
        showsSevenDayQuota: Bool,
        activity: WidgetActivityState,
        sourceTitle: String,
        transportTitle: String,
        connection: WidgetConnectionState,
        batteryPercent: Int?,
        lastSyncDate: Date?
    ) {
        self.generatedAt = generatedAt
        self.quotaSource = quotaSource
        self.fiveHourRemainingPercent = Self.clamped(fiveHourRemainingPercent)
        self.sevenDayRemainingPercent = Self.clamped(sevenDayRemainingPercent)
        self.manualRemainingPercent = Self.clamped(manualRemainingPercent)
        self.showsFiveHourQuota = showsFiveHourQuota
        self.showsSevenDayQuota = showsSevenDayQuota
        self.activity = activity
        self.sourceTitle = sourceTitle
        self.transportTitle = transportTitle
        self.connection = connection
        self.batteryPercent = Self.clamped(batteryPercent)
        self.lastSyncDate = lastSyncDate
    }

    var contentSignature: String {
        let parts: [String] = [
            quotaSource.rawValue,
            fiveHourRemainingPercent.map { String($0) } ?? "-",
            sevenDayRemainingPercent.map { String($0) } ?? "-",
            manualRemainingPercent.map { String($0) } ?? "-",
            showsFiveHourQuota ? "1" : "0",
            showsSevenDayQuota ? "1" : "0",
            activity.rawValue,
            sourceTitle,
            transportTitle,
            connection.rawValue,
            batteryPercent.map { String($0) } ?? "-"
        ]
        return parts.joined(separator: "|")
    }

    static let preview = WidgetStatusSnapshot(
        generatedAt: Date(),
        quotaSource: .codex,
        fiveHourRemainingPercent: 82,
        sevenDayRemainingPercent: 64,
        manualRemainingPercent: nil,
        showsFiveHourQuota: true,
        showsSevenDayQuota: true,
        activity: .working,
        sourceTitle: "Codex · gpt-5.6-sol",
        transportTitle: "蓝牙",
        connection: .connected,
        batteryPercent: 92,
        lastSyncDate: Date().addingTimeInterval(-90)
    )

    private static func clamped(_ value: Int?) -> Int? {
        value.map { min(100, max(0, $0)) }
    }
}
