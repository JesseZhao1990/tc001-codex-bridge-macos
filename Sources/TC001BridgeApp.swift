import AppKit
import Combine
import SwiftUI

extension Notification.Name {
    static let showTC001Settings = Notification.Name("showTC001Settings")
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            self.showSettings()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard urls.contains(where: { $0.scheme == WidgetConstants.appURLScheme }) else { return }
        showSettings()
    }

    private func showSettings() {
        NotificationCenter.default.post(name: .showTC001Settings, object: nil)
    }
}

@main
struct TC001BridgeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = BridgeStore()
    @StateObject private var updateManager = AppUpdateManager()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(store: store)
        } label: {
            MenuBarLabel(store: store)
        }
        .menuBarExtraStyle(.window)

        Window("TC001 Bridge 设置", id: "settings") {
            SettingsView(store: store, updateManager: updateManager)
        }
        .defaultPosition(.center)
        .windowResizability(.contentSize)
    }
}

private struct MenuBarLabel: View {
    @ObservedObject var store: BridgeStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: store.menuBarIcon)
            if !store.menuBarQuotaTitle.isEmpty {
                Text(store.menuBarQuotaTitle)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
        }
            .accessibilityLabel("TC001 Bridge")
            .onReceive(NotificationCenter.default.publisher(for: .showTC001Settings)) { _ in
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            }
    }
}
