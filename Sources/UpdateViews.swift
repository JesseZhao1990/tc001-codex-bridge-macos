import SwiftUI

struct AppUpdateView: View {
    @ObservedObject var manager: AppUpdateManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 3) {
                    Text("TC001 Bridge")
                        .font(.title2.weight(.semibold))
                    Text("版本 \(manager.currentVersion)（\(manager.currentBuild)）")
                        .foregroundStyle(.secondary)
                }
            }

            Picker(
                "更新方式",
                selection: Binding(
                    get: { manager.mode },
                    set: { manager.setMode($0) }
                )
            ) {
                ForEach(AppUpdateMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 9) {
                if manager.isBusy {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: statusSymbol)
                        .foregroundStyle(statusColor)
                }
                Text(manager.statusText)
                    .lineLimit(2)
                Spacer()
            }

            Label(
                "安装前会校验 GitHub SHA-256、应用标识和代码签名",
                systemImage: "checkmark.shield"
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Button {
                    Task { await manager.checkForUpdates() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("检查更新")
                .disabled(manager.isBusy)

                Button {
                    manager.openReleasePage()
                } label: {
                    Label("发布页面", systemImage: "safari")
                }

                Spacer()

                if manager.hasAvailableUpdate {
                    Button {
                        Task { await manager.installAvailableUpdate() }
                    } label: {
                        Label("下载并安装", systemImage: "arrow.down.circle")
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button("完成") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(22)
        .frame(width: 460, height: 310)
        .task {
            if manager.status == .idle {
                await manager.checkForUpdates()
            }
        }
    }

    private var statusSymbol: String {
        switch manager.status {
        case .upToDate: return "checkmark.circle.fill"
        case .available: return "arrow.down.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        default: return "info.circle"
        }
    }

    private var statusColor: Color {
        switch manager.status {
        case .upToDate: return .green
        case .available: return .blue
        case .failed: return .red
        default: return .secondary
        }
    }
}
