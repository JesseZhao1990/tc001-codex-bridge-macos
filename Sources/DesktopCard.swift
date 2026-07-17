import AppKit
import SwiftUI

@MainActor
final class DesktopCardController: NSObject, ObservableObject, NSWindowDelegate {
    private static let frameAutosaveName = "TC001DesktopStatusCard"

    private weak var store: BridgeStore?
    private var panel: NSPanel?

    func apply(isVisible: Bool, alwaysOnTop: Bool, store: BridgeStore) {
        self.store = store

        guard isVisible else {
            panel?.orderOut(nil)
            return
        }

        let panel = panel ?? makePanel(store: store)
        panel.level = alwaysOnTop ? .floating : .normal
        panel.orderFrontRegardless()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        store?.desktopCardVisible = false
        sender.orderOut(nil)
        return false
    }

    private func makePanel(store: BridgeStore) -> NSPanel {
        let size = NSSize(width: 420, height: 302)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.title = "TC001 Bridge 状态卡片"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.animationBehavior = .utilityWindow
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.delegate = self

        let rootView = DesktopCardView(
            store: store,
            close: { [weak self] in
                self?.hideFromUser()
            }
        )
        panel.contentView = NSHostingView(rootView: rootView)
        panel.setContentSize(size)

        if !panel.setFrameUsingName(Self.frameAutosaveName) {
            positionAtTopRight(panel)
        }
        panel.setFrameAutosaveName(Self.frameAutosaveName)

        self.panel = panel
        return panel
    }

    private func hideFromUser() {
        store?.desktopCardVisible = false
        panel?.orderOut(nil)
    }

    private func positionAtTopRight(_ panel: NSPanel) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            panel.center()
            return
        }

        let visibleFrame = screen.visibleFrame
        let frame = panel.frame
        panel.setFrameOrigin(
            NSPoint(
                x: visibleFrame.maxX - frame.width - 24,
                y: visibleFrame.maxY - frame.height - 28
            )
        )
    }
}

private struct DesktopCardView: View {
    @ObservedObject var store: BridgeStore
    let close: () -> Void

    var body: some View {
        ZStack {
            DesktopCardBackground(activity: store.effectiveActivity)

            VStack(spacing: 14) {
                header
                quotaContent
                statusFooter
            }
            .padding(18)
        }
        .frame(width: 420, height: 302)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("TC001 Bridge 桌面状态卡片")
    }

    private var header: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.28, green: 0.39, blue: 1),
                                Color(red: 0.18, green: 0.76, blue: 0.95)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "circle.grid.3x3.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 40, height: 40)
            .shadow(color: Color.blue.opacity(0.24), radius: 10, y: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text("TC001 BRIDGE")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .tracking(0.5)
                Text("CODEX DESK STATUS")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 6)

            ActivityBadge(activity: store.effectiveActivity)

            CardIconButton(
                systemImage: store.desktopCardAlwaysOnTop ? "pin.fill" : "pin.slash",
                help: store.desktopCardAlwaysOnTop ? "取消始终置顶" : "始终置顶"
            ) {
                store.desktopCardAlwaysOnTop.toggle()
            }

            CardIconButton(systemImage: "xmark", help: "隐藏桌面卡片", action: close)
        }
    }

    @ViewBuilder
    private var quotaContent: some View {
        if store.tokenMode == .codex {
            HStack(spacing: 10) {
                if store.showsFiveHourQuota {
                    DesktopQuotaTile(
                        eyebrow: "5 HOUR",
                        title: "5 小时额度",
                        percent: store.fiveHourRemainingPercent,
                        systemImage: "hourglass"
                    )
                }
                if store.showsSevenDayQuota {
                    DesktopQuotaTile(
                        eyebrow: "7 DAY",
                        title: "7 天额度",
                        percent: store.sevenDayRemainingPercent,
                        systemImage: "calendar"
                    )
                }
            }
        } else {
            DesktopQuotaTile(
                eyebrow: "TOKEN",
                title: "Token 余量",
                percent: store.effectivePercent,
                systemImage: "chart.bar.fill"
            )
        }
    }

    private var statusFooter: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                StatusPill(
                    systemImage: "cpu",
                    title: store.tokenSourceTitle,
                    tint: store.effectiveActivity.color
                )
                StatusPill(
                    systemImage: store.transportSystemImage,
                    title: "\(store.transportTitle) · \(store.connectionState.title)",
                    tint: store.connectionState.color
                )
            }

            HStack(spacing: 8) {
                Label(
                    store.lastSyncDate.map {
                        "同步于 \($0.formatted(date: .omitted, time: .shortened))"
                    } ?? "等待首次同步",
                    systemImage: "arrow.triangle.2.circlepath"
                )

                if let battery = store.deviceStats.battery {
                    Text("·")
                    Label("\(battery)%", systemImage: "battery.100")
                }

                Spacer()

                Button {
                    store.forceSync()
                } label: {
                    Label("立即同步", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .help("立即同步额度和设备状态")
            }
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
        }
    }
}

private struct DesktopCardBackground: View {
    let activity: ActivityState

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)

            LinearGradient(
                colors: [
                    Color.white.opacity(0.13),
                    Color.blue.opacity(0.055),
                    activity.color.opacity(0.055)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.blue.opacity(0.13))
                .frame(width: 190, height: 190)
                .blur(radius: 46)
                .offset(x: -178, y: -126)

            Circle()
                .fill(activity.color.opacity(0.1))
                .frame(width: 150, height: 150)
                .blur(radius: 42)
                .offset(x: 194, y: 126)
        }
    }
}

private struct DesktopQuotaTile: View {
    let eyebrow: String
    let title: String
    let percent: Int?
    let systemImage: String

    private var value: Int {
        min(100, max(0, percent ?? 0))
    }

    private var tint: Color {
        guard let percent else { return .secondary }
        switch percent {
        case 51...100: return .green
        case 21...50: return .yellow
        default: return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label(eyebrow, systemImage: systemImage)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(.secondary)
                Spacer()
                Circle()
                    .fill(tint)
                    .frame(width: 6, height: 6)
                    .shadow(color: tint.opacity(0.55), radius: 4)
            }

            HStack(alignment: .lastTextBaseline, spacing: 5) {
                Text(percent.map(String.init) ?? "--")
                    .font(.system(size: 35, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                if percent != nil {
                    Text("%")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.72), tint],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * Double(value) / 100)
                }
            }
            .frame(height: 6)
            .opacity(percent == nil ? 0.45 : 1)
        }
        .padding(13)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(Color.primary.opacity(0.045))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        }
    }
}

private struct ActivityBadge: View {
    let activity: ActivityState
    @State private var pulsing = false

    var body: some View {
        HStack(spacing: 7) {
            ZStack {
                Circle()
                    .stroke(activity.color.opacity(0.3), lineWidth: 4)
                    .frame(width: 14, height: 14)
                    .scaleEffect(pulsing && activity == .working ? 1.45 : 0.75)
                    .opacity(pulsing && activity == .working ? 0 : 1)
                Circle()
                    .fill(activity.color)
                    .frame(width: 7, height: 7)
                    .shadow(color: activity.color.opacity(0.65), radius: 4)
            }
            Text(activity.desktopTitle)
                .lineLimit(1)
        }
        .font(.system(size: 11, weight: .bold, design: .rounded))
        .foregroundStyle(activity.color)
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(activity.color.opacity(0.11), in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(activity.color.opacity(0.15), lineWidth: 1)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.15).repeatForever(autoreverses: false)) {
                pulsing = true
            }
        }
    }
}

private struct StatusPill: View {
    let systemImage: String
    let title: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
            Text(title)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.system(size: 10, weight: .semibold, design: .rounded))
        .padding(.horizontal, 9)
        .frame(maxWidth: .infinity, minHeight: 25, alignment: .leading)
        .background(Color.primary.opacity(0.045), in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        }
        .help(title)
    }
}

private struct CardIconButton: View {
    let systemImage: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 28, height: 28)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .background(Color.primary.opacity(0.055), in: Circle())
        .help(help)
    }
}

private extension ActivityState {
    var desktopTitle: String {
        switch self {
        case .idle: return "空闲"
        case .working: return "工作中"
        case .waiting: return "待确认"
        case .error: return "异常"
        }
    }
}
