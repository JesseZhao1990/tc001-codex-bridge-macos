import AppKit
import Foundation
import SwiftUI
import WidgetKit

private struct TC001WidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetStatusSnapshot?
}

private struct TC001WidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> TC001WidgetEntry {
        TC001WidgetEntry(date: Date(), snapshot: .preview)
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (TC001WidgetEntry) -> Void
    ) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        loadEntry(completion: completion)
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<TC001WidgetEntry>) -> Void
    ) {
        loadEntry { entry in
            completion(
                Timeline(
                    entries: [entry],
                    policy: .after(Date().addingTimeInterval(5 * 60))
                )
            )
        }
    }

    private func loadEntry(completion: @escaping (TC001WidgetEntry) -> Void) {
        var request = URLRequest(
            url: WidgetConstants.statusEndpoint,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 2
        )
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("TC001BridgeWidget", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { data, response, _ in
            let statusCode = (response as? HTTPURLResponse)?.statusCode
            let snapshot = statusCode == 200
                ? data.flatMap { try? JSONDecoder().decode(WidgetStatusSnapshot.self, from: $0) }
                : nil
            completion(TC001WidgetEntry(date: Date(), snapshot: snapshot))
        }
        .resume()
    }
}

struct TC001BridgeStatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: WidgetConstants.kind,
            provider: TC001WidgetProvider()
        ) { entry in
            TC001WidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetBackground(activity: entry.snapshot?.activity)
                }
                .widgetURL(WidgetConstants.appURL)
        }
        .configurationDisplayName("TC001 Bridge")
        .description("查看 Codex 额度、模型工作状态和 TC001 连接状态。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct TC001BridgeWidgetBundle: WidgetBundle {
    var body: some Widget {
        TC001BridgeStatusWidget()
    }
}

private struct TC001WidgetView: View {
    let entry: TC001WidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                switch family {
                case .systemSmall:
                    SmallStatusView(snapshot: snapshot)
                default:
                    MediumStatusView(snapshot: snapshot)
                }
            } else {
                OfflineStatusView()
            }
        }
        .accessibilityElement(children: .contain)
    }
}

private struct MediumStatusView: View {
    let snapshot: WidgetStatusSnapshot

    var body: some View {
        VStack(spacing: 10) {
            WidgetHeader(snapshot: snapshot)

            HStack(spacing: 8) {
                ForEach(Array(snapshot.metrics.enumerated()), id: \.offset) { _, metric in
                    QuotaTile(metric: metric)
                }
            }

            HStack(spacing: 8) {
                InfoPill(
                    systemImage: "cpu",
                    text: snapshot.sourceTitle,
                    tint: snapshot.activity.color
                )
                InfoPill(
                    systemImage: snapshot.transportSystemImage,
                    text: snapshot.deviceStatusTitle,
                    tint: snapshot.connection.color
                )
            }
        }
    }
}

private struct SmallStatusView: View {
    let snapshot: WidgetStatusSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                AppMark(size: 27)
                Text("TC001")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(0.5)
                Spacer(minLength: 4)
                StatusDot(activity: snapshot.activity)
            }

            if snapshot.metrics.count == 1, let metric = snapshot.metrics.first {
                VStack(alignment: .leading, spacing: 2) {
                    Text(metric.shortTitle)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text(metric.valueText)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        if metric.percent != nil {
                            Text("%")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                    ProgressBar(percent: metric.percent, tint: metric.tint)
                }
            } else {
                HStack(spacing: 8) {
                    ForEach(Array(snapshot.metrics.enumerated()), id: \.offset) { _, metric in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(metric.shortTitle)
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .tracking(0.7)
                                .foregroundStyle(.secondary)
                            Text(metric.compactValueText)
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .monospacedDigit()
                            ProgressBar(percent: metric.percent, tint: metric.tint)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 5) {
                Image(systemName: snapshot.transportSystemImage)
                    .foregroundStyle(snapshot.connection.color)
                Text(snapshot.deviceStatusTitle)
                    .lineLimit(1)
                Spacer(minLength: 2)
                if let battery = snapshot.batteryPercent {
                    Label("\(battery)%", systemImage: "battery.100")
                        .labelStyle(.titleAndIcon)
                }
            }
            .font(.system(size: 9, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
        }
    }
}

private struct WidgetHeader: View {
    let snapshot: WidgetStatusSnapshot

    var body: some View {
        HStack(spacing: 9) {
            AppMark(size: 32)

            VStack(alignment: .leading, spacing: 1) {
                Text("TC001 BRIDGE")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(0.6)
                Text("CODEX STATUS")
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: true, vertical: false)

            Spacer(minLength: 5)

            HStack(spacing: 6) {
                StatusDot(activity: snapshot.activity)
                Text(snapshot.activity.title)
            }
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(snapshot.activity.color)
            .padding(.horizontal, 9)
            .frame(height: 25)
            .background(snapshot.activity.color.opacity(0.12), in: Capsule())

            if let lastSyncDate = snapshot.lastSyncDate {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text(lastSyncDate, style: .relative)
                }
                .font(.system(size: 8, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            }
        }
    }
}

private struct AppMark: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.25, green: 0.39, blue: 1),
                            Color(red: 0.12, green: 0.74, blue: 0.94)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: "circle.grid.3x3.fill")
                .font(.system(size: size * 0.48, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: Color.blue.opacity(0.2), radius: 6, y: 3)
    }
}

private struct StatusDot: View {
    let activity: WidgetActivityState

    var body: some View {
        Circle()
            .fill(activity.color)
            .frame(width: 7, height: 7)
            .shadow(color: activity.color.opacity(0.65), radius: 3)
            .accessibilityLabel(activity.title)
    }
}

private struct QuotaTile: View {
    let metric: WidgetQuotaMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Label(metric.shortTitle, systemImage: metric.systemImage)
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .tracking(0.9)
                    .foregroundStyle(.secondary)
                Spacer()
                Circle()
                    .fill(metric.tint)
                    .frame(width: 5, height: 5)
            }

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(metric.valueText)
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .monospacedDigit()
                if metric.percent != nil {
                    Text("%")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            ProgressBar(percent: metric.percent, tint: metric.tint)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }
}

private struct ProgressBar: View {
    let percent: Int?
    let tint: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.09))
                Capsule()
                    .fill(tint)
                    .frame(
                        width: geometry.size.width *
                            CGFloat(min(100, max(0, percent ?? 0))) / 100
                    )
            }
        }
        .frame(height: 4)
        .opacity(percent == nil ? 0.4 : 1)
    }
}

private struct InfoPill: View {
    let systemImage: String
    let text: String
    let tint: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
            Text(text)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.system(size: 8, weight: .semibold, design: .rounded))
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, minHeight: 21, alignment: .leading)
        .background(Color.primary.opacity(0.045), in: Capsule())
    }
}

private struct OfflineStatusView: View {
    var body: some View {
        VStack(spacing: 9) {
            AppMark(size: 40)
            Text("TC001 Bridge")
                .font(.system(size: 14, weight: .bold, design: .rounded))
            Label("应用未运行", systemImage: "power")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            Text("点按小组件启动应用并恢复实时状态")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct WidgetBackground: View {
    let activity: WidgetActivityState?

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.14),
                    (activity?.color ?? .cyan).opacity(0.08),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill((activity?.color ?? .blue).opacity(0.1))
                .frame(width: 150, height: 150)
                .blur(radius: 38)
                .offset(x: 130, y: 75)
        }
    }
}

private struct WidgetQuotaMetric {
    let shortTitle: String
    let systemImage: String
    let percent: Int?

    var valueText: String {
        percent.map(String.init) ?? "--"
    }

    var compactValueText: String {
        percent.map { "\($0)%" } ?? "--"
    }

    var tint: Color {
        guard let percent else { return .secondary }
        switch percent {
        case 51...100: return .green
        case 21...50: return .yellow
        default: return .red
        }
    }
}

private extension WidgetStatusSnapshot {
    var metrics: [WidgetQuotaMetric] {
        switch quotaSource {
        case .manual:
            return [
                WidgetQuotaMetric(
                    shortTitle: "TOKEN",
                    systemImage: "chart.bar.fill",
                    percent: manualRemainingPercent
                )
            ]
        case .codex:
            var metrics: [WidgetQuotaMetric] = []
            if showsFiveHourQuota {
                metrics.append(
                    WidgetQuotaMetric(
                        shortTitle: "5 HOUR",
                        systemImage: "hourglass",
                        percent: fiveHourRemainingPercent
                    )
                )
            }
            if showsSevenDayQuota {
                metrics.append(
                    WidgetQuotaMetric(
                        shortTitle: "7 DAY",
                        systemImage: "calendar",
                        percent: sevenDayRemainingPercent
                    )
                )
            }
            return metrics
        }
    }

    var transportSystemImage: String {
        transportTitle == "蓝牙"
            ? "antenna.radiowaves.left.and.right"
            : "wifi"
    }

    var deviceStatusTitle: String {
        "\(transportTitle) · \(connection.title)"
    }
}

private extension WidgetActivityState {
    var title: String {
        switch self {
        case .idle: return "空闲"
        case .working: return "工作中"
        case .waiting: return "待确认"
        case .error: return "异常"
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
}

private extension WidgetConnectionState {
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
