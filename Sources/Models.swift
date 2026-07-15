import SwiftUI

typealias ActivityState = AIActivityState

extension AIActivityState {

    var title: String {
        switch self {
        case .idle: return "空闲"
        case .working: return "工作中"
        case .waiting: return "待确认"
        case .error: return "异常"
        }
    }

    var systemImage: String {
        switch self {
        case .idle: return "checkmark.circle.fill"
        case .working: return "bolt.circle.fill"
        case .waiting: return "questionmark.bubble.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .idle: return .yellow
        case .working: return .green
        case .waiting: return .blue
        case .error: return .red
        }
    }

    var animationFrameCount: Int {
        switch self {
        case .idle: return 1
        case .working: return 8
        case .waiting: return 6
        case .error: return 2
        }
    }

    var animationInterval: TimeInterval {
        switch self {
        case .idle: return 0
        case .working: return 0.7
        case .waiting: return 0.35
        case .error: return 0.9
        }
    }
}

enum QuotaKind: String, CaseIterable {
    case fiveHour
    case sevenDay
}

enum QuotaDisplayMode: Int, CaseIterable {
    case fiveHourOnly = 1
    case sevenDayOnly = 2
    case both = 3

    init(persistedRawValue: Int?) {
        self = persistedRawValue.flatMap(Self.init(rawValue:)) ?? .both
    }

    var showsFiveHour: Bool {
        self == .fiveHourOnly || self == .both
    }

    var showsSevenDay: Bool {
        self == .sevenDayOnly || self == .both
    }

    var displayedQuotas: [QuotaKind] {
        switch self {
        case .fiveHourOnly: return [.fiveHour]
        case .sevenDayOnly: return [.sevenDay]
        case .both: return [.fiveHour, .sevenDay]
        }
    }

    func quota(forPage page: Int) -> QuotaKind {
        let quotas = displayedQuotas
        let index = ((page % quotas.count) + quotas.count) % quotas.count
        return quotas[index]
    }

    func settingVisibility(of quota: QuotaKind, to isVisible: Bool) -> QuotaDisplayMode {
        let showsFiveHour = quota == .fiveHour ? isVisible : showsFiveHour
        let showsSevenDay = quota == .sevenDay ? isVisible : showsSevenDay

        switch (showsFiveHour, showsSevenDay) {
        case (true, true): return .both
        case (true, false): return .fiveHourOnly
        case (false, true): return .sevenDayOnly
        case (false, false): return self
        }
    }
}

enum QuotaPageSchedule {
    static let cycleDuration: TimeInterval = 10

    static func duration(for page: Int) -> TimeInterval {
        page.isMultiple(of: 2) ? 7 : 3
    }

    static func page(at elapsed: TimeInterval, displayMode: QuotaDisplayMode) -> Int {
        guard displayMode == .both else { return 0 }
        let position = max(0, elapsed).truncatingRemainder(dividingBy: cycleDuration)
        return position < duration(for: 0) ? 0 : 1
    }
}

struct LampTestSession {
    static let visibleDuration: TimeInterval = 4
    static let deliveryTimeout: TimeInterval = 15

    private(set) var activity: ActivityState?
    private(set) var visibleUntil: Date?
    private var requestedAt: Date?
    private var generation = 0

    mutating func begin(_ activity: ActivityState, at date: Date) {
        generation &+= 1
        self.activity = activity
        requestedAt = date
        visibleUntil = nil
    }

    func deliveryGeneration(for activity: ActivityState) -> Int? {
        self.activity == activity ? generation : nil
    }

    mutating func markDisplayed(generation deliveredGeneration: Int, at date: Date) {
        guard deliveredGeneration == generation, activity != nil, visibleUntil == nil else { return }
        visibleUntil = date.addingTimeInterval(Self.visibleDuration)
    }

    mutating func expireIfNeeded(at date: Date) -> Bool {
        guard activity != nil else { return false }
        let deadline = visibleUntil ?? requestedAt?.addingTimeInterval(Self.deliveryTimeout)
        guard let deadline, date >= deadline else { return false }
        activity = nil
        requestedAt = nil
        visibleUntil = nil
        return true
    }
}

enum TokenMode: String, CaseIterable, Identifiable {
    case codex
    case manualBridge

    var id: String { rawValue }

    var title: String {
        switch self {
        case .codex: return "Codex 自动"
        case .manualBridge: return "手动 / Bridge"
        }
    }
}

enum DeviceTransportMode: String, CaseIterable, Identifiable {
    case automatic
    case wifi
    case bluetooth

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: return "自动"
        case .wifi: return "Wi-Fi"
        case .bluetooth: return "蓝牙"
        }
    }
}

enum AWTRIXUsageDisplay: Equatable {
    case single(percent: Int)
    case codexQuotas(
        fiveHour: Int?,
        sevenDay: Int?,
        displayMode: QuotaDisplayMode
    )

    var signature: String {
        switch self {
        case let .single(percent):
            return "single:\(percent)"
        case let .codexQuotas(fiveHour, sevenDay, displayMode):
            return "quota:\(fiveHour.map(String.init) ?? "-"):\(sevenDay.map(String.init) ?? "-"):\(displayMode.rawValue)"
        }
    }
}

enum DeviceConnectionState: Equatable {
    case unknown
    case checking
    case connected
    case failed(String)

    var title: String {
        switch self {
        case .unknown: return "尚未检测"
        case .checking: return "正在连接"
        case .connected: return "已连接"
        case .failed: return "连接失败"
        }
    }

    var color: Color {
        switch self {
        case .unknown: return .secondary
        case .checking: return .orange
        case .connected: return .green
        case .failed: return .red
        }
    }
}

struct CodexSnapshot: Equatable {
    var activity: ActivityState
    var contextRemainingPercent: Int?
    var usedTokens: Int?
    var contextWindow: Int?
    var model: String?
    var sessionName: String
    var updatedAt: Date
}

struct DeviceStats: Equatable {
    var version: String?
    var appName: String?
    var battery: Int?
}

struct NativeAppsSettings: Equatable {
    static let supportedBLEMask: UInt8 = 0x1F

    var showTime: Bool
    var showDate: Bool
    var showTemperature: Bool
    var showHumidity: Bool
    var showBattery: Bool

    init(
        showTime: Bool = false,
        showDate: Bool = false,
        showTemperature: Bool = false,
        showHumidity: Bool = false,
        showBattery: Bool = false
    ) {
        self.showTime = showTime
        self.showDate = showDate
        self.showTemperature = showTemperature
        self.showHumidity = showHumidity
        self.showBattery = showBattery
    }

    init(bleMask: UInt8) {
        showTime = bleMask & (1 << 0) != 0
        showDate = bleMask & (1 << 1) != 0
        showTemperature = bleMask & (1 << 2) != 0
        showHumidity = bleMask & (1 << 3) != 0
        showBattery = bleMask & (1 << 4) != 0
    }

    var bleMask: UInt8 {
        (showTime ? 1 << 0 : 0) |
            (showDate ? 1 << 1 : 0) |
            (showTemperature ? 1 << 2 : 0) |
            (showHumidity ? 1 << 3 : 0) |
            (showBattery ? 1 << 4 : 0)
    }
}
