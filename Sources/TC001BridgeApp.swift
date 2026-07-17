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

    private func showSettings() {
        NotificationCenter.default.post(name: .showTC001Settings, object: nil)
    }
}

@main
struct TC001BridgeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = BridgeStore()
    @StateObject private var updateManager = AppUpdateManager()
    @StateObject private var desktopCardController = DesktopCardController()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(store: store)
        } label: {
            MenuBarLabel(store: store, desktopCardController: desktopCardController)
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
    @ObservedObject var desktopCardController: DesktopCardController
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
            .onAppear {
                updateDesktopCard()
            }
            .onChange(of: store.desktopCardVisible) { _ in
                updateDesktopCard()
            }
            .onChange(of: store.desktopCardAlwaysOnTop) { _ in
                updateDesktopCard()
            }
            .onReceive(NotificationCenter.default.publisher(for: .showTC001Settings)) { _ in
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            }
    }

    private func updateDesktopCard() {
        desktopCardController.apply(
            isVisible: store.desktopCardVisible,
            alwaysOnTop: store.desktopCardAlwaysOnTop,
            store: store
        )
    }
}
