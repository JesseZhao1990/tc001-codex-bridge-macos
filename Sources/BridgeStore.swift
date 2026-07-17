import AppKit
import Combine
import Foundation
import SwiftUI

@MainActor
final class BridgeStore: ObservableObject {
    private enum DefaultsKey {
        static let deviceAddress = "deviceAddress"
        static let transportMode = "transportMode"
        static let tokenMode = "tokenMode"
        static let quotaDisplayMode = "quotaDisplayMode"
        static let manualPercent = "manualPercent"
        static let autoMonitor = "autoMonitor"
        static let showQuotaInMenuBar = "showQuotaInMenuBar"
        static let desktopCardVisible = "desktopCardVisible"
        static let desktopCardAlwaysOnTop = "desktopCardAlwaysOnTop"
    }

    @Published var deviceAddress: String {
        didSet {
            defaults.set(deviceAddress, forKey: DefaultsKey.deviceAddress)
            lastSyncedSignature = nil
            nativeAppsLoaded = false
            nativeAppsLoading = false
            nativeAppsEditedLocally = false
            nativeAppsError = nil
            savedNativeApps = nil
            automaticUsesBluetooth = false
        }
    }

    @Published var transportMode: DeviceTransportMode {
        didSet {
            defaults.set(transportMode.rawValue, forKey: DefaultsKey.transportMode)
            automaticUsesBluetooth = false
            activeTransport = nil
            lastSyncedSignature = nil
            scheduleSync(switchToApp: true)
            testConnection()
        }
    }

    @Published var tokenMode: TokenMode {
        didSet {
            defaults.set(tokenMode.rawValue, forKey: DefaultsKey.tokenMode)
            if tokenMode == .codex, oldValue != .codex {
                quotaPage = 0
                quotaCycleStartUptime = nil
            }
            scheduleSync()
        }
    }

    @Published var quotaDisplayMode: QuotaDisplayMode {
        didSet {
            guard quotaDisplayMode != oldValue else { return }
            defaults.set(quotaDisplayMode.rawValue, forKey: DefaultsKey.quotaDisplayMode)
            quotaPage = 0
            quotaCycleStartUptime = nil
            lastSyncedSignature = nil
            scheduleSync()
        }
    }

    @Published var manualPercent: Double {
        didSet {
            defaults.set(manualPercent, forKey: DefaultsKey.manualPercent)
        }
    }

    @Published var autoMonitorEnabled: Bool {
        didSet {
            defaults.set(autoMonitorEnabled, forKey: DefaultsKey.autoMonitor)
            scheduleSync()
        }
    }

    @Published var showQuotaInMenuBar: Bool {
        didSet {
            defaults.set(showQuotaInMenuBar, forKey: DefaultsKey.showQuotaInMenuBar)
        }
    }

    @Published var desktopCardVisible: Bool {
        didSet {
            defaults.set(desktopCardVisible, forKey: DefaultsKey.desktopCardVisible)
        }
    }

    @Published var desktopCardAlwaysOnTop: Bool {
        didSet {
            defaults.set(desktopCardAlwaysOnTop, forKey: DefaultsKey.desktopCardAlwaysOnTop)
        }
    }

    @Published var nativeApps = NativeAppsSettings() {
        didSet {
            guard !updatingNativeAppsFromDevice, oldValue != nativeApps else { return }
            nativeAppsEditedLocally = true
        }
    }
    @Published private(set) var nativeAppsLoaded = false
    @Published private(set) var nativeAppsLoading = false
    @Published private(set) var nativeAppsApplying = false
    @Published private(set) var nativeAppsEditedLocally = false
    @Published private(set) var nativeAppsError: String?

    @Published private(set) var activeAIStatus: AIStatusSnapshot?
    @Published private(set) var connectionState: DeviceConnectionState = .unknown
    @Published private(set) var bluetoothState: AWTRIXBLEClient.ConnectionState = .idle
    @Published private(set) var activeTransport: DeviceTransportMode?
    @Published private(set) var deviceStats = DeviceStats()
    @Published private(set) var bridgeReady = false
    @Published private(set) var bridgeError: String?
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var lastError: String?
    @Published private(set) var lampTestActivity: ActivityState?

    let appName = "codex"
    let bridgePort: UInt16 = 8765

    private let defaults: UserDefaults
    private let aiProviders: [AIProvider]
    private let bleClient: AWTRIXBLEClient
    private var providerCoordinator: AIProviderCoordinator?
    private var localServer: LocalBridgeServer?
    private var timer: Timer?
    private var syncInFlight = false
    private var pendingForceSync = false
    private var pendingSwitchToApp = false
    private var lastSyncedSignature: String?
    private var lastAttemptDate = Date.distantPast
    private var externalActiveRequests = 0
    private var externalErrorUntil: Date?
    private var savedNativeApps: NativeAppsSettings?
    private var updatingNativeAppsFromDevice = false
    private var deviceRebootInProgress = false
    private var animationFrame = 0
    private var lastAnimationDate = Date.distantPast
    private var quotaPage = 0
    private var quotaCycleStartUptime: TimeInterval?
    private var quotaWarningFrame = 0
    private var automaticUsesBluetooth = false
    private var lampTestSession = LampTestSession()

    init(
        defaults: UserDefaults = .standard,
        aiProviders: [AIProvider] = [CodexProvider()],
        bleClient: AWTRIXBLEClient = AWTRIXBLEClient()
    ) {
        self.defaults = defaults
        self.aiProviders = aiProviders
        self.bleClient = bleClient
        self.deviceAddress = defaults.string(forKey: DefaultsKey.deviceAddress) ?? "awtrix.local"
        self.transportMode = DeviceTransportMode(
            rawValue: defaults.string(forKey: DefaultsKey.transportMode) ?? ""
        ) ?? .automatic
        self.tokenMode = TokenMode(rawValue: defaults.string(forKey: DefaultsKey.tokenMode) ?? "") ?? .codex
        self.quotaDisplayMode = QuotaDisplayMode(
            persistedRawValue: defaults.object(forKey: DefaultsKey.quotaDisplayMode) as? Int
        )
        self.manualPercent = defaults.object(forKey: DefaultsKey.manualPercent) == nil
            ? 73
            : defaults.double(forKey: DefaultsKey.manualPercent)
        self.autoMonitorEnabled = defaults.object(forKey: DefaultsKey.autoMonitor) == nil
            ? true
            : defaults.bool(forKey: DefaultsKey.autoMonitor)
        self.showQuotaInMenuBar = defaults.object(forKey: DefaultsKey.showQuotaInMenuBar) == nil
            ? true
            : defaults.bool(forKey: DefaultsKey.showQuotaInMenuBar)
        self.desktopCardVisible = defaults.object(forKey: DefaultsKey.desktopCardVisible) == nil
            ? true
            : defaults.bool(forKey: DefaultsKey.desktopCardVisible)
        self.desktopCardAlwaysOnTop = defaults.object(forKey: DefaultsKey.desktopCardAlwaysOnTop) == nil
            ? true
            : defaults.bool(forKey: DefaultsKey.desktopCardAlwaysOnTop)

        DispatchQueue.main.async { [weak self] in
            self?.start()
        }
    }

    deinit {
        timer?.invalidate()
        providerCoordinator?.stop()
        localServer?.stop()
        bleClient.stop()
    }

    var effectivePercent: Int {
        if tokenMode == .codex {
            switch quotaDisplayMode {
            case .fiveHourOnly:
                return fiveHourRemainingPercent ?? 0
            case .sevenDayOnly:
                return sevenDayRemainingPercent ?? 0
            case .both:
                return fiveHourRemainingPercent ?? sevenDayRemainingPercent ?? 0
            }
        }
        return min(100, max(0, Int(manualPercent.rounded())))
    }

    var fiveHourRemainingPercent: Int? {
        guard tokenMode == .codex else { return nil }
        return activeAIStatus?.quota?.window(minutes: 300)?.remainingPercent
    }

    var sevenDayRemainingPercent: Int? {
        guard tokenMode == .codex else { return nil }
        return activeAIStatus?.quota?.window(minutes: 10_080)?.remainingPercent
    }

    var usageDisplay: AWTRIXUsageDisplay {
        switch tokenMode {
        case .codex:
            return .codexQuotas(
                fiveHour: fiveHourRemainingPercent,
                sevenDay: sevenDayRemainingPercent,
                displayMode: quotaDisplayMode
            )
        case .manualBridge:
            return .single(percent: effectivePercent)
        }
    }

    var effectiveActivity: ActivityState {
        if let lampTestActivity {
            return lampTestActivity
        }
        if let externalErrorUntil, externalErrorUntil > Date() {
            return .error
        }
        if externalActiveRequests > 0 {
            return .working
        }
        guard autoMonitorEnabled else { return .idle }
        return activeAIStatus?.activity ?? .idle
    }

    var tokenSourceTitle: String {
        if tokenMode == .codex {
            guard let status = activeAIStatus else { return "Codex · 等待额度数据" }
            if let modelName = status.modelName {
                return "\(status.providerID.displayName) · \(modelName)"
            }
            return status.providerID.displayName
        }
        return "手动 / Bridge"
    }

    func quotaText(_ percent: Int?) -> String {
        percent.map { "\($0)%" } ?? "--"
    }

    var showsFiveHourQuota: Bool {
        quotaDisplayMode.showsFiveHour
    }

    var showsSevenDayQuota: Bool {
        quotaDisplayMode.showsSevenDay
    }

    func setQuota(_ quota: QuotaKind, isVisible: Bool) {
        quotaDisplayMode = quotaDisplayMode.settingVisibility(of: quota, to: isVisible)
    }

    var bridgeAddress: String {
        "http://127.0.0.1:\(bridgePort)"
    }

    var transportTitle: String {
        switch activeTransport {
        case .wifi: return "Wi-Fi"
        case .bluetooth: return "蓝牙"
        case .automatic, .none: return transportMode.title
        }
    }

    var transportSystemImage: String {
        activeTransport == .bluetooth || transportMode == .bluetooth
            ? "antenna.radiowaves.left.and.right"
            : "wifi"
    }

    var nativeAppsControlsEnabled: Bool {
        usesBluetoothForSettings ? bluetoothState.isReady : true
    }

    var nativeAppsApplyRequiresReboot: Bool {
        !usesBluetoothForSettings
    }

    var nativeAppsApplyButtonTitle: String {
        nativeAppsApplyRequiresReboot ? "应用并重启" : "应用"
    }

    var nativeAppsApplyingTitle: String {
        nativeAppsApplyRequiresReboot ? "正在重启 TC001" : "正在应用"
    }

    private var usesBluetoothForSettings: Bool {
        transportMode == .bluetooth ||
            (transportMode == .automatic &&
                (automaticUsesBluetooth || activeTransport == .bluetooth))
    }

    var menuBarIcon: String {
        switch effectiveActivity {
        case .idle: return "circle.grid.3x3.fill"
        case .working: return "bolt.horizontal.circle.fill"
        case .waiting: return "questionmark.bubble.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    var menuBarQuotaTitle: String {
        guard showQuotaInMenuBar else { return "" }
        switch tokenMode {
        case .codex:
            return QuotaSummaryFormatter.codexMenuBarTitle(
                displayMode: quotaDisplayMode,
                fiveHour: fiveHourRemainingPercent,
                sevenDay: sevenDayRemainingPercent
            )
        case .manualBridge:
            return QuotaSummaryFormatter.manualMenuBarTitle(percent: effectivePercent)
        }
    }

    var progressColor: Color {
        switch effectivePercent {
        case 51...100: return .green
        case 21...50: return .yellow
        default: return .red
        }
    }

    var hasPendingNativeAppsChanges: Bool {
        if let savedNativeApps {
            return nativeApps != savedNativeApps
        }
        return nativeAppsEditedLocally
    }

    func forceSync() {
        syncIfNeeded(force: true, switchToApp: true)
    }

    func testConnection() {
        connectionState = .checking
        lastError = nil
        nativeAppsLoading = true
        nativeAppsError = nil
        let address = deviceAddress
        let selectedTransport = transportMode
        Task { [weak self] in
            guard let self else { return }
            if selectedTransport == .bluetooth {
                await self.testBluetoothConnection()
                return
            }

            do {
                try await self.testWiFiConnection(address: address)
                self.automaticUsesBluetooth = false
                self.activeTransport = .wifi
                self.connectionState = .connected
            } catch {
                if selectedTransport == .automatic {
                    self.nativeAppsLoading = false
                    do {
                        try await self.bleClient.waitUntilReady()
                        let settings = try await self.bleClient.fetchNativeAppsSettings()
                        self.automaticUsesBluetooth = true
                        self.activeTransport = .bluetooth
                        self.acceptNativeAppsSettings(settings)
                        self.connectionState = .connected
                        self.lastError = nil
                        return
                    } catch {
                        let message = error.localizedDescription
                        self.nativeAppsLoading = false
                        self.nativeAppsError = message
                        self.connectionState = .failed(message)
                        self.lastError = message
                        return
                    }
                }

                let message = error.localizedDescription
                self.nativeAppsLoading = false
                self.nativeAppsError = message
                self.connectionState = .failed(message)
                self.lastError = message
            }
        }
    }

    func refreshNativeAppsSettings() {
        guard nativeAppsControlsEnabled, !nativeAppsApplying else { return }
        nativeAppsLoading = true
        nativeAppsError = nil
        let address = deviceAddress
        let useBluetooth = usesBluetoothForSettings
        Task { [weak self] in
            guard let self else { return }
            do {
                let settings = useBluetooth
                    ? try await self.bleClient.fetchNativeAppsSettings()
                    : try await AWTRIXClient.fetchNativeAppsSettings(address: address)
                self.acceptNativeAppsSettings(settings)
            } catch {
                self.nativeAppsLoading = false
                self.nativeAppsError = error.localizedDescription
            }
        }
    }

    func applyNativeAppsAndReboot() {
        guard nativeAppsControlsEnabled, hasPendingNativeAppsChanges, !nativeAppsApplying else { return }

        let address = deviceAddress
        let target = nativeApps
        let useBluetooth = usesBluetoothForSettings
        nativeAppsApplying = true
        nativeAppsError = nil
        deviceRebootInProgress = true
        connectionState = .checking

        Task { [weak self] in
            guard let self else { return }
            do {
                if useBluetooth {
                    let applied = try await self.bleClient.applyNativeAppsSettings(target)
                    guard applied == target else {
                        throw AWTRIXClientError.settingsVerificationFailed
                    }
                    self.acceptNativeAppsSettings(applied)
                    self.nativeAppsApplying = false
                    self.deviceRebootInProgress = false
                    self.activeTransport = .bluetooth
                    self.connectionState = .connected
                    self.lastSyncedSignature = nil
                    self.pendingForceSync = false
                    self.pendingSwitchToApp = false
                    self.syncIfNeeded(force: true, switchToApp: true)
                    return
                }

                try await AWTRIXClient.applyNativeAppsSettings(address: address, settings: target)
                try await AWTRIXClient.reboot(address: address)
                try? await Task.sleep(nanoseconds: 2_000_000_000)

                var recoveredStats: DeviceStats?
                var recoveredSettings: NativeAppsSettings?
                for _ in 0..<30 {
                    do {
                        let stats = try await AWTRIXClient.fetchStats(address: address)
                        let settings = try await AWTRIXClient.fetchNativeAppsSettings(address: address)
                        recoveredStats = stats
                        recoveredSettings = settings
                        break
                    } catch {
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                    }
                }

                guard let stats = recoveredStats, let settings = recoveredSettings else {
                    throw AWTRIXClientError.rebootTimedOut
                }
                guard settings == target else {
                    throw AWTRIXClientError.settingsVerificationFailed
                }

                self.deviceStats = stats
                self.acceptNativeAppsSettings(settings)
                self.nativeAppsApplying = false
                self.deviceRebootInProgress = false
                self.connectionState = .connected
                self.lastSyncedSignature = nil
                self.pendingForceSync = false
                self.pendingSwitchToApp = false
                self.syncIfNeeded(force: true, switchToApp: true)
            } catch {
                let message = error.localizedDescription
                self.nativeAppsApplying = false
                self.deviceRebootInProgress = false
                self.nativeAppsError = message
                self.connectionState = .failed(message)
                self.lastError = message
            }
        }
    }

    func testLamp(_ state: ActivityState) {
        let now = Date()
        lampTestSession.begin(state, at: now)
        lampTestActivity = state
        animationFrame = 0
        lastAnimationDate = now
        lastSyncedSignature = nil
        syncIfNeeded(force: true, switchToApp: true)
    }

    func quit() {
        providerCoordinator?.stop()
        localServer?.stop()
        NSApplication.shared.terminate(nil)
    }

    private func start() {
        guard timer == nil else { return }
        bleClient.onStateChange = { [weak self] state in
            guard let store = self else { return }
            DispatchQueue.main.async { [store] in
                store.bluetoothState = state
                if state.isReady,
                   store.transportMode == .bluetooth || store.automaticUsesBluetooth {
                    store.connectionState = .connected
                    store.syncIfNeeded(force: true, switchToApp: store.lastSyncDate == nil)
                }
            }
        }
        bleClient.onInfoChange = { [weak self] info in
            guard let store = self else { return }
            DispatchQueue.main.async { [store] in
                store.acceptBluetoothInfo(info)
            }
        }
        bleClient.start()

        let server = LocalBridgeServer(
            port: bridgePort,
            onCommand: { [weak self] command in
                guard let store = self else { return }
                DispatchQueue.main.async { [store] in store.handle(command) }
            },
            onState: { [weak self] ready, error in
                guard let store = self else { return }
                DispatchQueue.main.async { [store] in
                    store.bridgeReady = ready
                    store.bridgeError = error
                }
            }
        )
        localServer = server
        server.start()

        let coordinator = AIProviderCoordinator(
            providers: aiProviders,
            enabledProviderIDs: [.codex]
        ) { [weak self] status in
            guard let store = self else { return }
            DispatchQueue.main.async { [store] in
                store.acceptAIStatus(status)
            }
        }
        providerCoordinator = coordinator
        coordinator.start()

        testConnection()
        let timer = Timer(timeInterval: 0.35, repeats: true) { [weak self] _ in
            guard let store = self else { return }
            Task { @MainActor [store] in
                store.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        let now = Date()
        if lampTestSession.expireIfNeeded(at: now) {
            lampTestActivity = nil
            animationFrame = 0
            lastAnimationDate = now
            lastSyncedSignature = nil
            syncIfNeeded(force: true, switchToApp: false)
        }
        if let externalErrorUntil, externalErrorUntil <= now {
            self.externalErrorUntil = nil
            syncIfNeeded(force: true, switchToApp: false)
        }
        guard !deviceRebootInProgress else { return }
        advanceDisplayIfNeeded()

        let sinceLastSync = Date().timeIntervalSince(lastSyncDate ?? .distantPast)
        if sinceLastSync > 30 {
            syncIfNeeded(force: true, switchToApp: false)
        } else if case .failed = connectionState,
                  Date().timeIntervalSince(lastAttemptDate) > 10 {
            syncIfNeeded(force: true, switchToApp: false)
        }
    }

    private func scheduleSync(switchToApp: Bool = false) {
        guard timer != nil else { return }
        DispatchQueue.main.async { [weak self] in
            self?.syncIfNeeded(force: true, switchToApp: switchToApp)
        }
    }

    private func syncIfNeeded(force: Bool, switchToApp: Bool) {
        if deviceRebootInProgress {
            pendingForceSync = pendingForceSync || force
            pendingSwitchToApp = pendingSwitchToApp || switchToApp
            return
        }

        let display = usageDisplay
        let activity = effectiveActivity
        let frame = renderedAnimationFrame(for: activity)
        let displayPage = quotaPage
        let warningFrame = quotaWarningFrame
        let lampTestGeneration = lampTestSession.deliveryGeneration(for: activity)
        let signature = syncSignature(
            address: deviceAddress,
            display: display,
            activity: activity,
            frame: frame,
            quotaPage: displayPage,
            quotaWarningFrame: warningFrame
        )
        guard force || signature != lastSyncedSignature else { return }
        guard !syncInFlight else {
            pendingForceSync = pendingForceSync || force
            pendingSwitchToApp = pendingSwitchToApp || switchToApp
            return
        }

        syncInFlight = true
        lastAttemptDate = Date()
        if force || lastSyncDate == nil || connectionState != .connected {
            connectionState = .checking
        }
        lastError = nil

        let address = deviceAddress
        let shouldSwitch = switchToApp || lastSyncDate == nil
        Task { [weak self] in
            guard let self else { return }
            do {
                let usedTransport = try await self.sendDisplay(
                    address: address,
                    display: display,
                    activity: activity,
                    frame: frame,
                    quotaPage: displayPage,
                    quotaWarningFrame: warningFrame,
                    switchToApp: shouldSwitch
                )
                let stats = usedTransport == .wifi
                    ? try? await AWTRIXClient.fetchStats(address: address)
                    : nil
                self.syncInFlight = false
                self.lastSyncedSignature = signature
                self.lastSyncDate = Date()
                self.activeTransport = usedTransport
                self.connectionState = .connected
                if let lampTestGeneration {
                    self.lampTestSession.markDisplayed(
                        generation: lampTestGeneration,
                        at: self.lastSyncDate ?? Date()
                    )
                }
                if let stats { self.deviceStats = stats }

                let currentActivity = self.effectiveActivity
                let currentFrame = self.renderedAnimationFrame(for: currentActivity)
                let currentSignature = self.syncSignature(
                    address: self.deviceAddress,
                    display: self.usageDisplay,
                    activity: currentActivity,
                    frame: currentFrame,
                    quotaPage: self.quotaPage,
                    quotaWarningFrame: self.quotaWarningFrame
                )
                let pendingForce = self.pendingForceSync
                let pendingSwitch = self.pendingSwitchToApp
                self.pendingForceSync = false
                self.pendingSwitchToApp = false
                if pendingForce || pendingSwitch || currentSignature != signature {
                    self.syncIfNeeded(force: pendingForce || pendingSwitch, switchToApp: pendingSwitch)
                }
            } catch {
                let message = error.localizedDescription
                self.syncInFlight = false
                self.connectionState = .failed(message)
                self.lastError = message

                let pendingForce = self.pendingForceSync
                let pendingSwitch = self.pendingSwitchToApp
                self.pendingForceSync = false
                self.pendingSwitchToApp = false
                if pendingForce || pendingSwitch {
                    self.syncIfNeeded(force: true, switchToApp: pendingSwitch)
                }
            }
        }
    }

    private func handle(_ command: LocalBridgeCommand) {
        switch command {
        case .modelStart:
            externalActiveRequests += 1
        case .modelEnd:
            externalActiveRequests = max(0, externalActiveRequests - 1)
        case .modelError:
            externalActiveRequests = 0
            externalErrorUntil = Date().addingTimeInterval(20)
        case let .tokens(percent):
            manualPercent = Double(percent)
        case .refresh:
            break
        }
        syncIfNeeded(force: true, switchToApp: command.shouldSwitchApp)
    }

    private func advanceDisplayIfNeeded() {
        let activity = effectiveActivity
        let now = Date()
        var displayChanged = false

        if activity.animationFrameCount > 1,
           now.timeIntervalSince(lastAnimationDate) >= activity.animationInterval {
            lastAnimationDate = now
            animationFrame = (animationFrame + 1) % 1000
            displayChanged = true
        }

        if tokenMode == .codex {
            let uptime = ProcessInfo.processInfo.systemUptime
            if let quotaCycleStartUptime {
                let scheduledPage = QuotaPageSchedule.page(
                    at: uptime - quotaCycleStartUptime,
                    displayMode: quotaDisplayMode
                )
                if scheduledPage != quotaPage {
                    quotaPage = scheduledPage
                    displayChanged = true
                }
            } else {
                quotaCycleStartUptime = uptime
                quotaPage = 0
                displayChanged = true
            }
        }

        if displayChanged {
            syncIfNeeded(force: false, switchToApp: false)
        }
    }

    private func renderedAnimationFrame(for activity: ActivityState) -> Int {
        animationFrame % max(activity.animationFrameCount, 1)
    }

    private func sendDisplay(
        address: String,
        display: AWTRIXUsageDisplay,
        activity: ActivityState,
        frame: Int,
        quotaPage: Int,
        quotaWarningFrame: Int,
        switchToApp: Bool
    ) async throws -> DeviceTransportMode {
        func sendWiFi() async throws {
            try await AWTRIXClient.sync(
                address: address,
                appName: appName,
                usageDisplay: display,
                activity: activity,
                animationFrame: frame,
                quotaPage: quotaPage,
                quotaWarningFrame: quotaWarningFrame,
                switchToApp: switchToApp
            )
        }

        func sendBluetooth() async throws {
            let bluetoothFrame = AWTRIXClient.rgb565Frame(
                usageDisplay: display,
                activity: activity,
                animationFrame: frame,
                quotaPage: quotaPage,
                quotaWarningFrame: quotaWarningFrame
            )
            try await bleClient.sendFrame(bluetoothFrame, switchToApp: switchToApp)
        }

        switch transportMode {
        case .wifi:
            try await sendWiFi()
            return .wifi
        case .bluetooth:
            try await sendBluetooth()
            return .bluetooth
        case .automatic:
            if automaticUsesBluetooth {
                try await sendBluetooth()
                return .bluetooth
            }
            do {
                try await sendWiFi()
                return .wifi
            } catch {
                try await sendBluetooth()
                automaticUsesBluetooth = true
                return .bluetooth
            }
        }
    }

    private func syncSignature(
        address: String,
        display: AWTRIXUsageDisplay,
        activity: ActivityState,
        frame: Int,
        quotaPage: Int,
        quotaWarningFrame: Int
    ) -> String {
        "\(transportMode.rawValue)|\(address)|\(display.signature)|\(activity.rawValue)|\(frame)|\(quotaPage)|\(quotaWarningFrame)"
    }

    private func acceptNativeAppsSettings(_ settings: NativeAppsSettings) {
        let hadLocalEdits = nativeAppsEditedLocally
        savedNativeApps = settings
        if hadLocalEdits {
            nativeAppsEditedLocally = nativeApps != settings
        } else {
            updatingNativeAppsFromDevice = true
            nativeApps = settings
            updatingNativeAppsFromDevice = false
            nativeAppsEditedLocally = false
        }
        nativeAppsLoaded = true
        nativeAppsLoading = false
        nativeAppsError = nil
    }

    private func testWiFiConnection(address: String) async throws {
        let stats = try await AWTRIXClient.fetchStats(address: address)
        deviceStats = stats
        do {
            let settings = try await AWTRIXClient.fetchNativeAppsSettings(address: address)
            acceptNativeAppsSettings(settings)
        } catch {
            nativeAppsLoading = false
            nativeAppsError = error.localizedDescription
        }
    }

    private func testBluetoothConnection() async {
        do {
            try await bleClient.waitUntilReady()
            let settings = try await bleClient.fetchNativeAppsSettings()
            acceptNativeAppsSettings(settings)
            activeTransport = .bluetooth
            connectionState = .connected
            lastError = nil
        } catch {
            let message = error.localizedDescription
            nativeAppsLoading = false
            nativeAppsError = message
            connectionState = .failed(message)
            lastError = message
        }
    }

    private func acceptBluetoothInfo(_ info: String?) {
        guard let info,
              let data = info.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        if let version = json["firmware"] as? String {
            deviceStats.version = version
        }
        deviceStats.appName = appName
    }

    private func acceptAIStatus(_ status: AIStatusSnapshot?) {
        guard status != activeAIStatus else { return }
        activeAIStatus = status
        syncIfNeeded(force: false, switchToApp: lastSyncDate == nil)
    }
}

private extension LocalBridgeCommand {
    var shouldSwitchApp: Bool {
        switch self {
        case .refresh: return true
        default: return false
        }
    }
}
