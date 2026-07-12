import AppKit
import Darwin

@MainActor
enum UpdateRelaunchCoordinator {
    static func dismissAttachedSheets() {
        dismissAttachedSheets(in: NSApp.windows)
    }

    static func dismissAttachedSheets(in windows: [NSWindow]) {
        for sheet in windows {
            guard let parent = sheet.sheetParent else { continue }
            parent.endSheet(sheet)
            sheet.orderOut(nil)
        }
    }

    static func terminateApplication() {
        dismissAttachedSheets()

        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 2) {
            Darwin._exit(EXIT_SUCCESS)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NSApp.terminate(nil)
        }
    }
}
