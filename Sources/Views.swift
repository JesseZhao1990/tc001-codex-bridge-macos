import AppKit
import SwiftUI

struct MenuContentView: View {
    @ObservedObject var store: BridgeStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 9) {
                Image(systemName: "circle.grid.3x3.fill")
                    .font(.title2)
                    .foregroundStyle(.primary)
                Text("TC001 Bridge")
                    .font(.headline)
                Spacer()
                ConnectionDot(state: store.connectionState)
            }

            Divider()

            if store.tokenMode == .codex {
                HStack(alignment: .top, spacing: 12) {
                    if store.showsFiveHourQuota {
                        QuotaValueView(
                            title: "5 小时",
                            percent: store.fiveHourRemainingPercent
                        )
                    }
                    if store.showsSevenDayQuota {
                        QuotaValueView(
                            title: "7 天",
                            percent: store.sevenDayRemainingPercent
                        )
                    }
                    Spacer(minLength: 0)
                    Label(store.effectiveActivity.title, systemImage: store.effectiveActivity.systemImage)
                        .foregroundStyle(store.effectiveActivity.color)
                        .font(.callout.weight(.medium))
                        .padding(.top, 3)
                }
            } else {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TOKEN 余量")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(store.effectivePercent)%")
                            .font(.system(size: 34, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                    }
                    Spacer()
                    Label(store.effectiveActivity.title, systemImage: store.effectiveActivity.systemImage)
                        .foregroundStyle(store.effectiveActivity.color)
                        .font(.callout.weight(.medium))
                }

                ProgressView(value: Double(store.effectivePercent), total: 100)
                    .tint(store.progressColor)
            }

            VStack(alignment: .leading, spacing: 5) {
                Label(store.tokenSourceTitle, systemImage: "cpu")
                Label(
                    "\(store.transportTitle) · \(store.connectionState.title)",
                    systemImage: store.transportSystemImage
                )
                    .foregroundStyle(store.connectionState.color)
            }
            .font(.caption)

            Divider()

            HStack(spacing: 10) {
                Button {
                    store.forceSync()
                } label: {
                    Label("同步", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "settings")
                } label: {
                    Label("设置", systemImage: "gearshape")
                }

                Spacer()

                Button {
                    store.quit()
                } label: {
                    Image(systemName: "power")
                }
                .help("退出 TC001 Bridge")
            }
        }
        .padding(16)
        .frame(width: 310)
    }
}

struct SettingsView: View {
    @ObservedObject var store: BridgeStore
    @ObservedObject var updateManager: AppUpdateManager
    @State private var showingUpdatePanel = false

    private func quotaBinding(_ quota: QuotaKind) -> Binding<Bool> {
        Binding(
            get: {
                switch quota {
                case .fiveHour: return store.showsFiveHourQuota
                case .sevenDay: return store.showsSevenDayQuota
                }
            },
            set: { store.setQuota(quota, isVisible: $0) }
        )
    }

    var body: some View {
        Form {
            Section("TC001") {
                Picker("连接方式", selection: $store.transportMode) {
                    ForEach(DeviceTransportMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                HStack {
                    TextField("IP 地址", text: $store.deviceAddress)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { store.testConnection() }
                        .disabled(store.nativeAppsApplying)
                    Button {
                        store.testConnection()
                    } label: {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                    }
                    .help("测试连接")
                    .disabled(store.nativeAppsApplying)
                }
                .disabled(store.transportMode == .bluetooth)

                LabeledContent("状态") {
                    HStack(spacing: 7) {
                        ConnectionDot(state: store.connectionState)
                        Text("\(store.transportTitle) · \(store.connectionState.title)")
                    }
                }

                if store.transportMode != .wifi {
                    LabeledContent("蓝牙", value: store.bluetoothState.title)
                }

                if let version = store.deviceStats.version {
                    LabeledContent("AWTRIX 版本", value: version)
                }
                if let battery = store.deviceStats.battery {
                    LabeledContent("电量", value: "\(battery)%")
                }
                if case let .failed(message) = store.connectionState {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }

            Section("内置页面") {
                Group {
                    Toggle(isOn: $store.nativeApps.showTime) {
                        Label("时间", systemImage: "clock")
                    }
                    Toggle(isOn: $store.nativeApps.showDate) {
                        Label("日期", systemImage: "calendar")
                    }
                    Toggle(isOn: $store.nativeApps.showTemperature) {
                        Label("温度", systemImage: "thermometer.medium")
                    }
                    Toggle(isOn: $store.nativeApps.showHumidity) {
                        Label("湿度", systemImage: "drop.fill")
                    }
                    Toggle(isOn: $store.nativeApps.showBattery) {
                        Label("电量", systemImage: "battery.100")
                    }
                }
                .disabled(store.nativeAppsApplying || !store.nativeAppsControlsEnabled)

                HStack {
                    if store.nativeAppsApplying {
                        ProgressView()
                            .controlSize(.small)
                        Text(store.nativeAppsApplyingTitle)
                            .foregroundStyle(.secondary)
                    } else if store.nativeAppsLoading {
                        ProgressView()
                            .controlSize(.small)
                        Text(store.nativeAppsEditedLocally ? "正在读取，已保留你的更改" : "正在读取")
                            .foregroundStyle(.secondary)
                    } else if store.hasPendingNativeAppsChanges {
                        Label("有未应用的更改", systemImage: "circle.dotted")
                            .foregroundStyle(.orange)
                    } else if store.nativeAppsLoaded {
                        Label("已与 TC001 同步", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("可直接编辑", systemImage: "hand.tap")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if !store.nativeAppsApplying {
                        Button {
                            store.refreshNativeAppsSettings()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .help("重新读取 TC001 页面开关")
                        .disabled(store.nativeAppsLoading || !store.nativeAppsControlsEnabled)
                    }

                    if store.hasPendingNativeAppsChanges && !store.nativeAppsApplying {
                        Button {
                            store.applyNativeAppsAndReboot()
                        } label: {
                            Label(
                                store.nativeAppsApplyButtonTitle,
                                systemImage: store.nativeAppsApplyRequiresReboot
                                    ? "arrow.clockwise.circle"
                                    : "checkmark.circle"
                            )
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!store.nativeAppsControlsEnabled)
                    }
                }

                if let error = store.nativeAppsError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }

            Section("额度") {
                Picker("数据来源", selection: $store.tokenMode) {
                    ForEach(TokenMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if store.tokenMode == .manualBridge {
                    HStack {
                        Slider(value: $store.manualPercent, in: 0...100, step: 1) { editing in
                            if !editing { store.forceSync() }
                        }
                        Text("\(Int(store.manualPercent.rounded()))%")
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                    }
                } else {
                    QuotaToggleRow(
                        title: "5 小时额度",
                        value: store.quotaText(store.fiveHourRemainingPercent),
                        isOn: quotaBinding(.fiveHour),
                        canTurnOff: store.showsSevenDayQuota
                    )
                    QuotaToggleRow(
                        title: "7 天额度",
                        value: store.quotaText(store.sevenDayRemainingPercent),
                        isOn: quotaBinding(.sevenDay),
                        canTurnOff: store.showsFiveHourQuota
                    )
                    Text("至少选择一种额度；开关会同步影响 TC001、菜单栏和桌面小组件。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("显示") {
                Toggle("菜单栏显示额度", isOn: $store.showQuotaInMenuBar)

                if #available(macOS 14.0, *) {
                    LabeledContent("桌面小组件") {
                        Label("已随应用安装", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }

                    Text("在桌面空白处点按右键，选择“编辑小组件”，搜索“TC001 Bridge”后添加。小组件的位置和尺寸由 macOS 管理。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    LabeledContent("桌面小组件") {
                        Label("需要 macOS 14", systemImage: "exclamationmark.circle")
                            .foregroundStyle(.orange)
                    }
                }
            }

            Section("模型状态") {
                ModelStatusCard(store: store)

                Toggle("自动监测 Codex", isOn: $store.autoMonitorEnabled)

                HStack {
                    Text("测试")
                    Spacer()
                    ForEach(ActivityState.allCases, id: \.self) { state in
                        Button {
                            store.testLamp(state)
                        } label: {
                            Label(state.title, systemImage: state.systemImage)
                                .foregroundStyle(state.color)
                        }
                    }
                }
            }

            Section("本机 Bridge") {
                LabeledContent("服务") {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(store.bridgeReady ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(store.bridgeReady ? "运行中" : "未运行")
                    }
                }
                LabeledContent("地址", value: store.bridgeAddress)
                    .textSelection(.enabled)
                if let bridgeError = store.bridgeError {
                    Text(bridgeError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("最近同步") {
                LabeledContent("时间", value: store.lastSyncDate?.formatted(date: .omitted, time: .standard) ?? "尚未同步")
                if let app = store.deviceStats.appName {
                    LabeledContent("TC001 页面", value: app)
                }
            }

            Section("关于") {
                Button {
                    showingUpdatePanel = true
                } label: {
                    HStack {
                        Label("版本", systemImage: "info.circle")
                        Spacer()
                        if updateManager.hasAvailableUpdate {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 7, height: 7)
                        }
                        Text(updateManager.currentVersion)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .formStyle(.grouped)
        .frame(width: 540, height: 720)
        .sheet(isPresented: $showingUpdatePanel) {
            AppUpdateView(manager: updateManager)
        }
        .task {
            updateManager.start()
        }
        .toolbar {
            ToolbarItem {
                Button {
                    store.forceSync()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                .help("立即同步")
            }
        }
    }
}

private struct ModelStatusCard: View {
    @ObservedObject var store: BridgeStore

    var body: some View {
        HStack(spacing: 14) {
            StatusLampPreview(activity: store.effectiveActivity)

            VStack(alignment: .leading, spacing: 5) {
                Text(store.effectiveActivity.heroTitle)
                    .font(.headline)
                Text(store.effectiveActivity.heroSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    if store.tokenMode == .codex {
                        if store.showsFiveHourQuota {
                            Label("5H \(store.quotaText(store.fiveHourRemainingPercent))", systemImage: "hourglass")
                        }
                        if store.showsSevenDayQuota {
                            Label("7D \(store.quotaText(store.sevenDayRemainingPercent))", systemImage: "calendar")
                        }
                    } else {
                        Label("\(store.effectivePercent)%", systemImage: "chart.bar.fill")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct StatusLampPreview: View {
    let activity: ActivityState

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.88))
            Circle()
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
            Circle()
                .fill(activity.color.opacity(0.2))
                .padding(5)
            Circle()
                .fill(activity.color)
                .padding(9)
                .shadow(color: activity.color.opacity(0.65), radius: 7)
            Circle()
                .fill(Color.white.opacity(0.72))
                .frame(width: 7, height: 7)
                .offset(x: -9, y: -9)
        }
        .frame(width: 58, height: 58)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("模型状态：\(activity.title)")
    }
}

private struct QuotaToggleRow: View {
    let title: String
    let value: String
    @Binding var isOn: Bool
    let canTurnOff: Bool

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Toggle("显示\(title)", isOn: $isOn)
                .labelsHidden()
                .disabled(isOn && !canTurnOff)
                .accessibilityLabel("显示\(title)")
        }
    }
}

private struct QuotaValueView: View {
    let title: String
    let percent: Int?

    private var valueText: String {
        percent.map { "\($0)%" } ?? "--"
    }

    private var color: Color {
        guard let percent else { return .secondary }
        switch percent {
        case 51...100: return .green
        case 21...50: return .yellow
        default: return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(valueText)
                .font(.system(size: 27, weight: .semibold, design: .rounded))
                .monospacedDigit()
            ProgressView(value: Double(percent ?? 0), total: 100)
                .tint(color)
                .opacity(percent == nil ? 0.35 : 1)
        }
        .frame(width: 68, alignment: .leading)
    }
}

private struct ConnectionDot: View {
    let state: DeviceConnectionState

    var body: some View {
        Circle()
            .fill(state.color)
            .frame(width: 9, height: 9)
            .overlay {
                if state == .checking {
                    ProgressView()
                        .controlSize(.mini)
                        .scaleEffect(0.65)
                }
            }
            .accessibilityLabel(state.title)
    }
}

private extension ActivityState {
    var heroTitle: String {
        switch self {
        case .idle: return "大模型 ZZZ 躺平中"
        case .working: return "大模型 RUN 工作中"
        case .waiting: return "大模型正等你确认"
        case .error: return "模型状态异常"
        }
    }

    var heroSubtitle: String {
        switch self {
        case .idle: return "Codex 当前没有运行中的任务"
        case .working: return "Codex 正在处理任务"
        case .waiting: return "Codex 已暂停，等待审批或回答问题"
        case .error: return "最近一次任务执行异常"
        }
    }
}
